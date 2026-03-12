#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

#include "rknpu_ioctl.h"

static const char *default_node = "/dev/dri/by-path/platform-fde40000.npu-render";

int main(int argc, char **argv)
{
    const char *node = argc > 1 ? argv[1] : default_node;
    struct rknpu_mem_create create = {0};
    struct rknpu_mem_map map = {0};
    struct rknpu_mem_destroy destroy = {0};
    volatile unsigned char *ptr = NULL;
    size_t size = 1024 * 1024;
    int fd;
    int ret;

    fd = open(node, O_RDWR | O_CLOEXEC);
    if (fd < 0) {
        fprintf(stderr, "open %s failed: %d (%s)\n", node, errno,
                strerror(errno));
        return 1;
    }

    create.flags = RKNPU_MEM_NON_CONTIGUOUS | RKNPU_MEM_WRITE_COMBINE;
    create.size = size;
    create.iommu_domain_id = 0;
    create.core_mask = 0;

    ret = ioctl(fd, DRM_IOCTL_RKNPU_MEM_CREATE, &create);
    if (ret < 0) {
        fprintf(stderr, "MEM_CREATE failed on %s: %d (%s)\n", node, errno,
                strerror(errno));
        close(fd);
        return 2;
    }

    map.handle = create.handle;
    ret = ioctl(fd, DRM_IOCTL_RKNPU_MEM_MAP, &map);
    if (ret < 0) {
        fprintf(stderr, "MEM_MAP failed on %s: %d (%s)\n", node, errno,
                strerror(errno));
        destroy.handle = create.handle;
        destroy.obj_addr = create.obj_addr;
        ioctl(fd, DRM_IOCTL_RKNPU_MEM_DESTROY, &destroy);
        close(fd);
        return 3;
    }

    ptr = mmap(NULL, create.size, PROT_READ | PROT_WRITE, MAP_SHARED, fd,
               (off_t)map.offset);
    if (ptr == MAP_FAILED) {
        fprintf(stderr, "mmap failed on %s: %d (%s)\n", node, errno,
                strerror(errno));
        destroy.handle = create.handle;
        destroy.obj_addr = create.obj_addr;
        ioctl(fd, DRM_IOCTL_RKNPU_MEM_DESTROY, &destroy);
        close(fd);
        return 4;
    }

    ptr[0] = 0x5a;
    if (ptr[0] != 0x5a) {
        fprintf(stderr, "mmap verification failed on %s\n", node);
        munmap((void *)ptr, create.size);
        destroy.handle = create.handle;
        destroy.obj_addr = create.obj_addr;
        ioctl(fd, DRM_IOCTL_RKNPU_MEM_DESTROY, &destroy);
        close(fd);
        return 5;
    }

    munmap((void *)ptr, create.size);

    destroy.handle = create.handle;
    destroy.obj_addr = create.obj_addr;
    ret = ioctl(fd, DRM_IOCTL_RKNPU_MEM_DESTROY, &destroy);
    if (ret < 0) {
        fprintf(stderr, "MEM_DESTROY failed on %s: %d (%s)\n", node, errno,
                strerror(errno));
        close(fd);
        return 6;
    }

    printf("DRM GEM path OK on %s\n", node);
    printf("  handle=%u\n", create.handle);
    printf("  size=%" PRIu64 "\n", (uint64_t)create.size);
    printf("  dma_addr=0x%" PRIx64 "\n", (uint64_t)create.dma_addr);
    printf("  obj_addr=0x%" PRIx64 "\n", (uint64_t)create.obj_addr);
    printf("  map_offset=0x%" PRIx64 "\n", (uint64_t)map.offset);

    close(fd);
    return 0;
}
