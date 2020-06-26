post_checkout_hook="$(git rev-parse --git-path hooks)/post-checkout"
echo "#! /usr/bin/env bash" > "$post_checkout_hook"
echo "mkdir -p addons/MagicaVoxelImporter; \
    echo 'Updating plugins'; \
    cp -v MagicaVoxel-Importer/addons/MagicaVoxelImporter/* addons/MagicaVoxelImporter" >> "$post_checkout_hook"
chmod +x "$post_checkout_hook"
"$post_checkout_hook"
