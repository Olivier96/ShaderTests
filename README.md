# Map Data Overlay - Shader-Based Geo Visualization

A Qt 6 QML application demonstrating shader-based color visualization overlay on a map. Data points with latitude/longitude coordinates and associated values are interpolated using Inverse Distance Weighting (IDW) to create smooth color gradients across the map surface.

## Features

- **Shader-based rendering**: Uses GLSL fragment shaders for efficient GPU-accelerated color interpolation
- **Inverse Distance Weighting**: Smooth interpolation between data points
- **Map-locked overlay**: Colors stay fixed to geographic coordinates as you pan/zoom
- **Interactive controls**: Adjust overlay opacity and influence radius in real-time
- **Color gradient**: Blue (low) -> Cyan -> Green -> Yellow -> Red (high) value mapping

## Architecture

```
┌─────────────────────────────────────────────┐
│                Main.qml                      │
│  ┌─────────────────────────────────────┐    │
│  │           Qt Map                     │    │
│  │  ┌───────────────────────────────┐  │    │
│  │  │     MapDataOverlay            │  │    │
│  │  │     (ShaderEffect)            │  │    │
│  │  │                               │  │    │
│  │  │  Uniforms:                    │  │    │
│  │  │  - viewport bounds (lat/lon)  │  │    │
│  │  │  - data points (lat,lon,val)  │  │    │
│  │  │  - influence radius           │  │    │
│  │  └───────────────────────────────┘  │    │
│  └─────────────────────────────────────┘    │
│                                              │
│  ListModel (10 sample data points)          │
└─────────────────────────────────────────────┘
```

## Shader Algorithm

The fragment shader performs per-pixel color interpolation:

1. **Coordinate Mapping**: Convert screen position to lat/lon based on current viewport
2. **IDW Interpolation**: For each pixel, calculate weighted average of nearby data points
3. **Color Mapping**: Map interpolated value (0-1) to color gradient
4. **Alpha Falloff**: Smooth transparency based on distance from nearest data point

```glsl
// IDW formula: value = Σ(wi * vi) / Σ(wi)
// where wi = 1 / d^p (d = distance, p = power parameter)
```

## Requirements

- Qt 6.5 or later
- Qt Modules: Quick, QuickControls2, Positioning, Location, ShaderTools
- CMake 3.16+
- C++17 compiler

## Building

```bash
# Create build directory
mkdir build && cd build

# Configure
cmake ..

# Build
cmake --build .

# Run
./appMapDataOverlay
```

## File Structure

```
ShaderTests/
├── CMakeLists.txt          # Build configuration
├── main.cpp                # Application entry point
├── Main.qml                # Main window with Map and controls
├── MapDataOverlay.qml      # ShaderEffect wrapper component
├── shaders/
│   ├── overlay.vert        # Vertex shader (pass-through)
│   └── overlay.frag        # Fragment shader (IDW interpolation)
├── compile_shaders.sh      # Manual shader compilation script
└── README.md
```

## Sample Data Points

The example includes 10 major cities with sample values:

| City | Latitude | Longitude | Value |
|------|----------|-----------|-------|
| Paris | 48.8566 | 2.3522 | 0.90 |
| London | 51.5074 | -0.1278 | 0.70 |
| New York | 40.7128 | -74.0060 | 0.85 |
| Tokyo | 35.6762 | 139.6503 | 0.60 |
| Sydney | -33.8688 | 151.2093 | 0.40 |
| Moscow | 55.7558 | 37.6173 | 0.30 |
| Rio de Janeiro | -22.9068 | -43.1729 | 0.75 |
| Mexico City | 19.4326 | -99.1332 | 0.50 |
| Singapore | 1.3521 | 103.8198 | 0.65 |
| New Delhi | 28.6139 | 77.2090 | 0.80 |

## Scaling to 400K Points

For large datasets (400K+ points), consider these approaches:

1. **Texture-based data**: Pack point data into a texture and sample in shader
2. **Pre-computed grid**: Interpolate data to a regular grid texture
3. **Level-of-detail**: Use different resolution grids based on zoom level
4. **Tiled approach**: Divide world into tiles with local point subsets

## Future Enhancements

- [ ] Hover system for point info display
- [ ] Binary file loading for large datasets
- [ ] Texture-based point storage
- [ ] Level-of-detail rendering
- [ ] Custom color gradient configuration

## License

MIT License
