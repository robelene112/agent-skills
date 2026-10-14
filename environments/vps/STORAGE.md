# VPS storage

Applies to David's current netcup VPS only. Verified on 2026-10-14 using `lsblk`,
`findmnt` and `df`. Recheck mounts and available space before sizeable writes.

| Storage | Device | Mount | Filesystem | Observed disk size |
| --- | --- | --- | --- | --- |
| System disk | `/dev/vda4`, partition of `vda` | `/` | ext4 | `vda`: 128 GiB |
| Additional disk | `/dev/vdb1`, partition of `vdb` | `/mnt/storage` | ext4 | `vdb`: 200 GiB |

`/mnt` itself belongs to the root filesystem. The additional disk begins at
`/mnt/storage`; putting files elsewhere under `/mnt` does not use it.

For large new build artifacts, caches or temporary data, consider a suitable
writable task directory under `/mnt/storage` and verify its ownership and free
space. Existing application paths and data locations remain governed by their
project's operations guide.

The mount root was owned by `root:root` with mode `0755` at inspection. Do not
assume an ordinary user can write directly there; use an appropriate task
directory rather than changing ownership of the mount root.

Check the actual target, especially when symlinks or bind mounts are involved:

```bash
findmnt --target /mnt/storage
df -h / /mnt/storage
```

Free-space figures are observations, not permanent configuration. Moving an
existing application database, filestore or Docker storage is a separate task.
