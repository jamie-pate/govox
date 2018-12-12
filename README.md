# govox
Godot / vox demo project for voxel importer point_sprite style

![Static Preview](./govox.png)

# Usage
Check out this repository then run the following:

```
git submodule init
git submodule update --recursive
chmod +x *.sh #maybe not needed on linux
./deploy-git-hooks.sh #deploys a post-checkout hook copying the addon into ./addons, (and runs it once)
```

Open the project in godot

It should look like this: [![Govox Preview](./govox.gif)](https://streamable.com/s/b318z/sxcuia)