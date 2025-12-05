#!/bin/bash

# Compile GLSL shaders to Qt Shader Baker format (.qsb)
# Requires Qt 6 shader tools (qsb) to be in PATH

SHADER_DIR="shaders"

echo "Compiling shaders..."

# Compile vertex shader
qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 \
    -o "${SHADER_DIR}/overlay.vert.qsb" \
    "${SHADER_DIR}/overlay.vert"

if [ $? -eq 0 ]; then
    echo "  ✓ overlay.vert.qsb"
else
    echo "  ✗ Failed to compile overlay.vert"
    exit 1
fi

# Compile fragment shader
qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 \
    -o "${SHADER_DIR}/overlay.frag.qsb" \
    "${SHADER_DIR}/overlay.frag"

if [ $? -eq 0 ]; then
    echo "  ✓ overlay.frag.qsb"
else
    echo "  ✗ Failed to compile overlay.frag"
    exit 1
fi

echo "All shaders compiled successfully!"
