/*
 * Redstone OpenBCM init probe gate.
 *
 * This wrapper does not implement Broadcom SDK logic. It gates execution of an
 * OpenBCM userland demo init binary behind Redstone-specific hardware checks.
 */
#define _XOPEN_SOURCE 700
#define _POSIX_C_SOURCE 200809L

#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>
#include <limits.h>

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

#ifndef DEFAULT_DEMO_INIT
#define DEFAULT_DEMO_INIT "/usr/sbin/demo_opennsa_init"
#endif
#ifndef DEFAULT_BCM_CONFIG
#define DEFAULT_BCM_CONFIG "/etc/switchd/redstone-stage1.bcm"
#endif
#define DEFAULT_PCI_ROOT "/sys/bus/pci/devices"
#define DEFAULT_DEV_ROOT "/dev"

struct options {
    int exec_mode;
    int accept_reset_risk;
    int use_lspci;
    const char *demo_path;
    const char *config_path;
    const char *pci_root;
    const char *dev_root;
};

static void usage(const char *prog)
{
    fprintf(stderr,
            "usage: %s [--dry-run|--exec] [--demo PATH] [--config PATH]\n"
            "          [--pci-root PATH] [--dev-root PATH] [--no-lspci]\n"
            "          [--i-accept-hardware-reset-risk]\n"
            "\n"
            "Default mode is --dry-run. --exec requires the explicit reset-risk flag.\n",
            prog);
}

static const char *env_or_default(const char *name, const char *fallback)
{
    const char *value = getenv(name);
    return value && value[0] ? value : fallback;
}

static int copy_path(char *dst, size_t dst_len, const char *a, const char *b)
{
    int n = snprintf(dst, dst_len, "%s/%s", a, b);
    return n >= 0 && (size_t)n < dst_len;
}

static int read_trimmed_file(const char *path, char *buf, size_t buf_len)
{
    FILE *fp = fopen(path, "r");
    size_t len;

    if (!fp)
        return -1;

    if (!fgets(buf, (int)buf_len, fp)) {
        fclose(fp);
        return -1;
    }
    fclose(fp);

    len = strlen(buf);
    while (len > 0 && isspace((unsigned char)buf[len - 1])) {
        buf[len - 1] = '\0';
        len--;
    }

    for (size_t i = 0; buf[i]; i++)
        buf[i] = (char)tolower((unsigned char)buf[i]);

    return 0;
}

static int path_is_readable_file(const char *path)
{
    struct stat st;

    if (stat(path, &st) != 0)
        return 0;
    if (!S_ISREG(st.st_mode))
        return 0;
    return access(path, R_OK) == 0;
}

static int path_is_executable_file(const char *path)
{
    struct stat st;

    if (stat(path, &st) != 0)
        return 0;
    if (!S_ISREG(st.st_mode))
        return 0;
    return access(path, R_OK | X_OK) == 0;
}

static int check_bde_node(const struct options *opts, const char *name)
{
    char path[PATH_MAX];
    struct stat st;

    if (!copy_path(path, sizeof(path), opts->dev_root, name)) {
        fprintf(stderr, "FAIL: BDE node path is too long for %s\n", name);
        return 1;
    }

    if (stat(path, &st) != 0) {
        fprintf(stderr, "FAIL: missing %s: %s\n", path, strerror(errno));
        return 1;
    }

    if (!S_ISCHR(st.st_mode)) {
        fprintf(stderr, "FAIL: %s exists but is not a character device\n", path);
        return 1;
    }

    if (access(path, R_OK | W_OK) != 0) {
        fprintf(stderr, "FAIL: %s is not readable and writable: %s\n", path, strerror(errno));
        return 1;
    }

    printf("PASS: BDE node present: %s\n", path);
    return 0;
}

static int check_sysfs_for_bcm56846(const struct options *opts)
{
    DIR *dir = opendir(opts->pci_root);
    struct dirent *ent;

    if (!dir) {
        fprintf(stderr, "WARN: cannot open PCI sysfs root %s: %s\n",
                opts->pci_root, strerror(errno));
        return 0;
    }

    while ((ent = readdir(dir)) != NULL) {
        char vendor_path[PATH_MAX];
        char device_path[PATH_MAX];
        char vendor[64];
        char device[64];
        char entry_root[PATH_MAX];

        if (strcmp(ent->d_name, ".") == 0 || strcmp(ent->d_name, "..") == 0)
            continue;

        if (!copy_path(entry_root, sizeof(entry_root), opts->pci_root, ent->d_name))
            continue;
        if (!copy_path(vendor_path, sizeof(vendor_path), entry_root, "vendor"))
            continue;
        if (!copy_path(device_path, sizeof(device_path), entry_root, "device"))
            continue;

        if (read_trimmed_file(vendor_path, vendor, sizeof(vendor)) != 0)
            continue;
        if (read_trimmed_file(device_path, device, sizeof(device)) != 0)
            continue;

        if (strcmp(vendor, "0x14e4") == 0 && strcmp(device, "0xb846") == 0) {
            printf("PASS: BCM56846 PCI ID found in sysfs: %s vendor=%s device=%s\n",
                   entry_root, vendor, device);
            closedir(dir);
            return 1;
        }
    }

    closedir(dir);
    return 0;
}

static int check_lspci_for_bcm56846(void)
{
    FILE *fp = popen("lspci -n 2>/dev/null", "r");
    char line[512];

    if (!fp) {
        fprintf(stderr, "WARN: cannot run lspci -n: %s\n", strerror(errno));
        return 0;
    }

    while (fgets(line, sizeof(line), fp)) {
        char lower[sizeof(line)];
        size_t i;

        for (i = 0; i + 1 < sizeof(lower) && line[i]; i++)
            lower[i] = (char)tolower((unsigned char)line[i]);
        lower[i] = '\0';

        if (strstr(lower, "14e4:b846") != NULL) {
            printf("PASS: BCM56846 PCI ID found with lspci: %s", line);
            pclose(fp);
            return 1;
        }
    }

    pclose(fp);
    return 0;
}

static int check_bcm56846_pci_id(const struct options *opts)
{
    if (check_sysfs_for_bcm56846(opts))
        return 0;

    if (opts->use_lspci && check_lspci_for_bcm56846())
        return 0;

    fprintf(stderr, "FAIL: exact BCM56846 PCI ID 14e4:b846 was not found\n");
    return 1;
}

static int parse_args(int argc, char **argv, struct options *opts)
{
    opts->exec_mode = 0;
    opts->accept_reset_risk = 0;
    opts->use_lspci = 1;
    opts->demo_path = env_or_default("OPENBCM_DEMO_INIT", DEFAULT_DEMO_INIT);
    opts->config_path = env_or_default("BCM_CONFIG_FILE", DEFAULT_BCM_CONFIG);
    opts->pci_root = DEFAULT_PCI_ROOT;
    opts->dev_root = DEFAULT_DEV_ROOT;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--dry-run") == 0) {
            opts->exec_mode = 0;
        } else if (strcmp(argv[i], "--exec") == 0) {
            opts->exec_mode = 1;
        } else if (strcmp(argv[i], "--i-accept-hardware-reset-risk") == 0) {
            opts->accept_reset_risk = 1;
        } else if (strcmp(argv[i], "--no-lspci") == 0) {
            opts->use_lspci = 0;
        } else if (strcmp(argv[i], "--demo") == 0 && i + 1 < argc) {
            opts->demo_path = argv[++i];
        } else if (strcmp(argv[i], "--config") == 0 && i + 1 < argc) {
            opts->config_path = argv[++i];
        } else if (strcmp(argv[i], "--pci-root") == 0 && i + 1 < argc) {
            opts->pci_root = argv[++i];
        } else if (strcmp(argv[i], "--dev-root") == 0 && i + 1 < argc) {
            opts->dev_root = argv[++i];
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            usage(argv[0]);
            exit(0);
        } else {
            fprintf(stderr, "FAIL: unknown or incomplete argument: %s\n", argv[i]);
            usage(argv[0]);
            return 1;
        }
    }

    return 0;
}

static int run_gate_checks(const struct options *opts)
{
    int failures = 0;

    printf("Redstone OpenBCM init probe gate\n");
    printf("mode=%s\n", opts->exec_mode ? "exec" : "dry-run");
    printf("demo=%s\n", opts->demo_path);
    printf("config=%s\n", opts->config_path);
    printf("pci_root=%s\n", opts->pci_root);
    printf("dev_root=%s\n", opts->dev_root);

    failures += check_bde_node(opts, "linux-kernel-bde");
    failures += check_bde_node(opts, "linux-user-bde");
    failures += check_bcm56846_pci_id(opts);

    if (!path_is_readable_file(opts->config_path)) {
        fprintf(stderr, "FAIL: BCM_CONFIG_FILE candidate is not readable: %s\n",
                opts->config_path);
        failures++;
    } else {
        printf("PASS: BCM config is readable: %s\n", opts->config_path);
    }

    if (!path_is_executable_file(opts->demo_path)) {
        if (opts->exec_mode) {
            fprintf(stderr, "FAIL: OpenBCM demo init binary is not executable: %s\n",
                    opts->demo_path);
            failures++;
        } else {
            fprintf(stderr, "WARN: OpenBCM demo init binary is not executable yet: %s\n",
                    opts->demo_path);
        }
    } else {
        printf("PASS: OpenBCM demo init binary is executable: %s\n", opts->demo_path);
    }

    if (opts->exec_mode && !opts->accept_reset_risk) {
        fprintf(stderr,
                "FAIL: --exec requires --i-accept-hardware-reset-risk\n");
        failures++;
    }

    return failures;
}

int main(int argc, char **argv)
{
    struct options opts;
    int failures;
    char *exec_argv[2];

    if (parse_args(argc, argv, &opts) != 0)
        return 2;

    failures = run_gate_checks(&opts);
    if (failures) {
        fprintf(stderr, "blocked: %d required check(s) failed\n", failures);
        return 1;
    }

    if (!opts.exec_mode) {
        printf("dry-run complete: ASIC init was not executed and no offload was proven\n");
        return 0;
    }

    if (setenv("BCM_CONFIG_FILE", opts.config_path, 1) != 0) {
        fprintf(stderr, "FAIL: cannot set BCM_CONFIG_FILE: %s\n", strerror(errno));
        return 1;
    }

    printf("exec: starting OpenBCM demo init binary now\n");
    fflush(stdout);

    exec_argv[0] = (char *)opts.demo_path;
    exec_argv[1] = NULL;
    execv(opts.demo_path, exec_argv);

    fprintf(stderr, "FAIL: execv(%s) failed: %s\n", opts.demo_path, strerror(errno));
    return 1;
}
