"""Far LOD for flora / ground clutter (ROADMAP P1 perf pass 3, art bible 8.3/8.7).

Unlike buildings (far_kit.py: hand-made far recipes), flora far models are the near model, joined into one mesh and
collapse-decimated to a triangle target. Same origin and axes as the near model, so FloraBatch can swap the MultiMesh
mesh without touching instance transforms. Node name "body__far" -> Art.model_far (no crease lines, no hull pass;
the screen-space depth outline still draws the silhouette).

Use:  m.export(OUT, far=flora_far.decimated(TARGET))     # TARGET = far triangles (<= near)
"""
import bpy
import bmesh

FAR = "body__far"


def _tris(me):
    return sum(len(p.vertices) - 2 for p in me.polygons)


def decimated(target=0, ratio=0.0, floor=48, min_ratio=0.04):
    """Returns a Model.export(far=...) hook: join copies of all group objects -> one "body__far" object,
    collapse-decimate to about `target` triangles, or `ratio` x near triangles (at least `floor`)
    (vertex colours interpolated, face smooth flags kept)."""
    def fn(objs):
        bm = bmesh.new()
        for ob in objs:
            tmp = ob.data.copy()
            tmp.transform(ob.matrix_world)
            bm.from_mesh(tmp)
            bpy.data.meshes.remove(tmp)
        me = bpy.data.meshes.new(FAR)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(FAR, me)
        bpy.context.scene.collection.objects.link(ob)
        n0 = _tris(me)
        goal = target if target > 0 else max(floor, int(n0 * ratio))
        if n0 <= goal:
            return n0
        mod = ob.modifiers.new("dec", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = max(min_ratio, float(goal) / n0)
        mod.use_collapse_triangulate = True
        dg = bpy.context.evaluated_depsgraph_get()
        me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        ob.modifiers.remove(mod)
        ob.data = me2
        bpy.data.meshes.remove(me)
        me2.name = FAR
        # fixed triangulation (the exporter's own split is not stable between runs)
        bm = bmesh.new()
        bm.from_mesh(me2)
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="EAR_CLIP")
        bm.to_mesh(me2)
        bm.free()
        return _tris(me2)
    return fn
