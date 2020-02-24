# Monitoring

## Check module load

```sh
dmesg | grep -i vfio
```

```sh
dmesg | grep -i -e DMAR -e IOMMU
```

## Monitor CPU, RAM, GPU usage

- CPU :

```sh
watch lscpu
```

```sh
intel-undervolt read
```

You can also use auto-cpufreq :

```sh
auto-cpufreq --log
```

- RAM :

```sh
ps_mem
```

- KVM :

`perf`

- GPU :

Install `intel_gpu_tools`

`intel_gpu_top`

- Profiles

`tune-adm active`

## CPU Governor

- cpupower
- intel-undervolt
- auto-cpufreq
- TLP
