#!/usr/bin/env python3
"""
plot_output.py - Delft3D FM output visualizer

Usage:
    plot_output <map_file.nc> [variable] [timestep]

Examples:
    plot_output /workspace/output/f34_map.nc
    plot_output /workspace/output/f34_map.nc s1
    plot_output /workspace/output/f34_map.nc ucx -1
    plot_output /workspace/output/f34_map.nc --list

Variables commonly found in Delft3D FM map output:
    s1         - Water surface elevation (m)
    waterdepth - Water depth (m)
    ucx        - Flow velocity, x-component (m/s)
    ucy        - Flow velocity, y-component (m/s)
    taus       - Bed shear stress (N/m2)
    sa1        - Salinity (ppt)
    tem1       - Temperature (deg C)
"""

import sys
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.tri as tri
import netCDF4 as nc


def find_var(ds, *candidates):
    """Return the first candidate variable name that exists in the dataset."""
    for name in candidates:
        if name in ds.variables:
            return name
    return None


def list_variables(ds):
    print("\nVariables with time dimension (plottable):")
    for v in ds.variables:
        var = ds.variables[v]
        if len(var.shape) == 2:
            long_name = getattr(var, 'long_name', '')
            units = getattr(var, 'units', '')
            print(f"  {v:20s} {str(var.shape):15s} {long_name} ({units})")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    map_file = sys.argv[1]
    ds = nc.Dataset(map_file)

    if '--list' in sys.argv:
        list_variables(ds)
        ds.close()
        return

    variable = sys.argv[2] if len(sys.argv) > 2 else 's1'
    timestep = int(sys.argv[3]) if len(sys.argv) > 3 else -1

    print(f"Opening:   {map_file}")
    print(f"Variable:  {variable}")
    print(f"Timestep:  {timestep}")

    # --- Validate requested variable ---
    if variable not in ds.variables:
        print(f"\nERROR: Variable '{variable}' not found.")
        list_variables(ds)
        ds.close()
        sys.exit(1)

    data = ds.variables[variable][timestep, :]
    units     = getattr(ds.variables[variable], 'units', '')
    long_name = getattr(ds.variables[variable], 'long_name', variable)

    # --- Time label ---
    time_label = f'timestep {timestep}'
    time_var = ds.variables.get('time')
    if time_var is not None:
        try:
            times = nc.num2date(time_var[:], time_var.units)
            time_label = str(times[timestep])
        except Exception:
            pass

    # --- Find mesh coordinates (handles both old and new Delft3D naming) ---
    node_x_name = find_var(ds, 'NetNode_x', 'mesh2d_node_x', 'node_x')
    node_y_name = find_var(ds, 'NetNode_y', 'mesh2d_node_y', 'node_y')
    conn_name   = find_var(ds, 'NetElemNode', 'mesh2d_face_nodes', 'face_node_connectivity')
    face_x_name = find_var(ds, 'FlowElem_xcc', 'mesh2d_face_x', 'face_x')
    face_y_name = find_var(ds, 'FlowElem_ycc', 'mesh2d_face_y', 'face_y')

    if node_x_name and conn_name:
        # --- Proper unstructured mesh triangulation ---
        x_nodes = ds.variables[node_x_name][:]
        y_nodes = ds.variables[node_y_name][:]
        face_nodes = ds.variables[conn_name][:]  # shape (nfaces, max_nodes_per_face)

        # Build triangles — Delft3D uses 1-based indexing; 0 = fill/missing node
        # Track face_index for each triangle so data values can be mapped correctly
        triangles = []
        tri_face_idx = []
        for i, face in enumerate(face_nodes):
            nodes = [int(n) - 1 for n in face if int(n) > 0]
            if len(nodes) == 3:
                triangles.append(nodes)
                tri_face_idx.append(i)
            elif len(nodes) == 4:
                triangles.append([nodes[0], nodes[1], nodes[2]])
                tri_face_idx.append(i)
                triangles.append([nodes[0], nodes[2], nodes[3]])
                tri_face_idx.append(i)

        # Map face data to triangles (each face may produce 1 or 2 triangles)
        data = data[np.array(tri_face_idx)]

        triang = tri.Triangulation(x_nodes, y_nodes, triangles)
        ds.close()

        fig, ax = plt.subplots(figsize=(10, 7))
        tpc = ax.tripcolor(triang, data, cmap='viridis', shading='flat')
        plt.colorbar(tpc, ax=ax, label=f'{long_name} ({units})')
        ax.set_aspect('equal')

    elif face_x_name:
        # --- Fallback: scatter plot at face centres ---
        print("Note: using face-centre scatter plot (no connectivity found)")
        x = ds.variables[face_x_name][:]
        y = ds.variables[face_y_name][:]
        ds.close()

        fig, ax = plt.subplots(figsize=(10, 7))
        sc = ax.scatter(x, y, c=data, cmap='viridis', s=20)
        plt.colorbar(sc, ax=ax, label=f'{long_name} ({units})')
        ax.set_aspect('equal')

    else:
        print("ERROR: Could not find mesh coordinates in this file.")
        ds.close()
        sys.exit(1)

    ax.set_title(f'Delft3D FM — {long_name}\n{time_label}')
    ax.set_xlabel('X (m)')
    ax.set_ylabel('Y (m)')
    plt.tight_layout()

    out = map_file.replace('.nc', f'_{variable}.png')
    plt.savefig(out, dpi=150)
    print(f"Saved:     {out}")
    plt.show()


if __name__ == '__main__':
    main()
