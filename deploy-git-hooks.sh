echo "#! /usr/bin/env bash" > ./.git/hooks/post-checkout
echo "cp MagicaVoxel-Importer/addons/MagicaVoxelImporter/* addons/MagicaVoxelImporter" >> ./.git/hooks/post-checkout
chmod +x ./.git/hooks/post-checkout
./.git/hooks/post-checkout
