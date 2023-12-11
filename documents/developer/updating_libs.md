
## Updating c to d headers

Download release binaries (or follow build instruction from https://github.com/jacob-carlborg/dstep)
    
```bash
wget https://github.com/jacob-carlborg/dstep/releases/download/v1.0.0/dstep-1.0.0-linux-x86_64.tar.xz
tar xf dstep-1.0.0-linux-x86_64.tar.xz
# Then copy the executable to a directory searched by your path, like the path you added when you set up your compiler
```

Convert header files
```
make dstep
```
