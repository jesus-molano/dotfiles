function dgpu --description "Run one command on the NVIDIA PRIME GPU"
    if test (count $argv) -eq 0
        echo "Usage: dgpu <command> [arguments...]" >&2
        return 2
    end
    if not command -q prime-run
        echo "prime-run is not installed; review the active CachyOS PRIME profile." >&2
        return 1
    end

    # Keep every NVIDIA offload variable scoped to this process. On systems
    # without PRIME the function exits before changing the environment.
    if test -f /usr/share/glvnd/egl_vendor.d/10_nvidia.json
        set -lx __EGL_VENDOR_LIBRARY_FILENAMES /usr/share/glvnd/egl_vendor.d/10_nvidia.json
    end
    if test -f /usr/share/vulkan/icd.d/nvidia_icd.json
        set -lx VK_DRIVER_FILES /usr/share/vulkan/icd.d/nvidia_icd.json
    end

    command prime-run $argv
end
