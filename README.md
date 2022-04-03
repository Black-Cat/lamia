# lamia
Small sdf editor

uses [nyancore](https://github.com/Black-Cat/nyancore)

![small_lamia](https://user-images.githubusercontent.com/10657551/142719390-d5692410-8b83-4eca-add8-772bfc73a364.png)

### Requirements

* zig 0.9
* Vulkan SDK (for developing, optional)

### How to build?
Clone repository with all submodules
```git clone --recurse-submodules git@github.com:Black-Cat/lamia.git```

Cross compilation is available

Release for windows is build with `zig build -Dtarget=x86_64-windows-gnu -Drelease-fast=true`

#### Linux
```
zig build
```
#### Windows
```
zig build -Dtarget=x86_64-windows-gnu
```

### Hot to run?

#### Linux
```
zig build run
```
#### Windows
```
zig build -Dtarget=x86_64-windows-gnu run
```

It is also possible to pass path to scene that will be opened on the application start

```
zig build run -- ../scene.ls

or

./zig-out/bin/lamia ../scene.ls
```

#### Feedback

Create an issue here, or send email to iblackcatw(at)gmail.com or discord `Black Cat!#5337`
