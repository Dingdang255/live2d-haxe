package live2d.cubism.ext;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.PositionTools;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;

/**
 * Compile-time `@:build` macro that parses a `.model3.json` file and
 * generates `public static var` constants for motion group names,
 * expression names, hit area names, parameter group names, and the
 * texture list.
 *
 * Prevents string typos: `HaruConstants.Motions.Idel` fails to compile,
 * while `HaruConstants.Motions.Idle` resolves to `"Idle"`.
 *
 * Usage:
 * ```haxe
 * @:build(live2d.cubism.ext.L2DModelConstants.build('assets/live2d/Haru/Haru.model3.json'))
 * class HaruConstants {}
 * ```
 *
 * Generates (for Haru):
 *   `HaruConstants.Motions.Idle`      == "Idle"
 *   `HaruConstants.Motions.TapBody`   == "TapBody"
 *   `HaruConstants.Expressions.F01`   == "F01"
 *   `HaruConstants.HitAreas.Head`     == "Head"
 *   `HaruConstants.Groups.EyeBlink`   == "EyeBlink"
 *   `HaruConstants.Groups.LipSync`    == "LipSync"
 *   `HaruConstants.Textures`          == ["Haru.2048/texture_00.png", ...]
 *
 * Path resolution: searches `-cp` classpaths via `Context.resolvePath`,
 * then tries the path as-is (absolute or relative to CWD). On failure,
 * reports a clear compile error listing attempted paths.
 */
class L2DModelConstants
{
    public static macro function build(model3JsonPath:String):Array<Field>
    {
        var fields = Context.getBuildFields();
        var pos = Context.currentPos();

        var fullPath = resolvePath(model3JsonPath, pos);
        var content = File.getContent(fullPath);
        var json = Json.parse(content);

        // Track used names within each section to deduplicate after sanitization.
        // Motions: object with group names as keys.
        if (json.FileReferences != null && json.FileReferences.Motions != null)
        {
            var used = new Map<String, Bool>();
            var objFields:Array<ObjectField> = [];
            for (groupName in Reflect.fields(json.FileReferences.Motions))
            {
                var safe = sanitizeName(groupName, used);
                objFields.push({field: safe, expr: macro $v{groupName}});
            }
            if (objFields.length > 0)
            {
                fields.push(makeStaticField("Motions", "Motion group names from model3.json",
                    {expr: EObjectDecl(objFields), pos: pos}, false));
            }
        }

        // Expressions: array of {Name, File}.
        if (json.FileReferences != null && json.FileReferences.Expressions != null)
        {
            var used = new Map<String, Bool>();
            var objFields:Array<ObjectField> = [];
            for (expr in cast(json.FileReferences.Expressions, Array<Dynamic>))
            {
                if (expr.Name == null) continue;
                var safe = sanitizeName(expr.Name, used);
                objFields.push({field: safe, expr: macro $v{expr.Name}});
            }
            if (objFields.length > 0)
            {
                fields.push(makeStaticField("Expressions", "Expression names from model3.json",
                    {expr: EObjectDecl(objFields), pos: pos}, false));
            }
        }

        // HitAreas: array of {Id, Name}. (Top-level in model3.json, not under FileReferences.)
        if (json.HitAreas != null)
        {
            var used = new Map<String, Bool>();
            var objFields:Array<ObjectField> = [];
            for (area in cast(json.HitAreas, Array<Dynamic>))
            {
                if (area.Name == null) continue;
                var safe = sanitizeName(area.Name, used);
                objFields.push({field: safe, expr: macro $v{area.Name}});
            }
            if (objFields.length > 0)
            {
                fields.push(makeStaticField("HitAreas", "Hit area names from model3.json",
                    {expr: EObjectDecl(objFields), pos: pos}, false));
            }
        }

        // Groups: array of {Target, Name, Ids} — only Target == "Parameter".
        if (json.Groups != null)
        {
            var used = new Map<String, Bool>();
            var objFields:Array<ObjectField> = [];
            for (grp in cast(json.Groups, Array<Dynamic>))
            {
                if (grp.Name == null) continue;
                var safe = sanitizeName(grp.Name, used);
                objFields.push({field: safe, expr: macro $v{grp.Name}});
            }
            if (objFields.length > 0)
            {
                fields.push(makeStaticField("Groups", "Parameter group names from model3.json",
                    {expr: EObjectDecl(objFields), pos: pos}, false));
            }
        }

        // Textures: array of strings. Cannot be `inline` (array literal),
        // so use a regular `static var`.
        if (json.FileReferences != null && json.FileReferences.Textures != null)
        {
            var texArr:Array<Expr> = [];
            for (tex in cast(json.FileReferences.Textures, Array<Dynamic>))
            {
                texArr.push(macro $v{tex});
            }
            if (texArr.length > 0)
            {
                var arrExpr:Expr = {expr: EArrayDecl(texArr), pos: pos};
                fields.push(makeStaticField("Textures", "Texture paths from model3.json",
                    arrExpr, false));
            }
        }

        return fields;
    }

    // ===== Internal =====

    static function resolvePath(path:String, pos:Position):String
    {
        // 1. Try Context.resolvePath (searches -cp classpaths)
        try
        {
            return Context.resolvePath(path);
        }
        catch (e:Dynamic) {}

        // 2. Try as-is (absolute or relative to CWD)
        if (FileSystem.exists(path))
        {
            return path;
        }

        // 3. Try relative to the file containing the @:build call
        try
        {
            var dir = haxe.io.Path.directory(PositionTools.getInfos(pos).file);
            if (dir != "" && dir != ".")
            {
                var candidate = haxe.io.Path.join([dir, path]);
                if (FileSystem.exists(candidate)) return candidate;
            }
        }
        catch (e:Dynamic) {}

        // Failed — report a clear error
        Context.error(
            'L2DModelConstants: cannot find model3.json at "$path". ' +
            'Tried: Context.resolvePath, CWD "${Sys.getCwd()}", and relative to source file.',
            pos
        );
        return null; // unreachable — Context.error throws
    }

    /**
     * Sanitizes a model3.json name into a valid Haxe identifier.
     * - Replaces any char not in [A-Za-z0-9_] with `_`.
     * - Prefixes with `_` if it starts with a digit.
     * - Deduplicates by appending `_2`, `_3`, etc.
     */
    static function sanitizeName(name:String, used:Map<String, Bool>):String
    {
        var safe = new StringBuf();
        for (i in 0...name.length)
        {
            var c = name.charAt(i);
            var code = name.charCodeAt(i);
            var isAlpha = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
            var isDigit = code >= 48 && code <= 57;
            if (isAlpha || isDigit || c == "_")
            {
                safe.add(c);
            }
            else
            {
                safe.add("_");
            }
        }
        var result = safe.toString();
        // Prefix if starts with digit
        var firstCode = result.length > 0 ? result.charCodeAt(0) : 0;
        if (firstCode >= 48 && firstCode <= 57)
        {
            result = "_" + result;
        }
        if (result == "") result = "_";

        // Deduplicate
        if (used.exists(result))
        {
            var n = 2;
            while (used.exists(result + "_" + n)) n++;
            result = result + "_" + n;
        }
        used.set(result, true);
        return result;
    }

    static function makeStaticField(name:String, doc:String, expr:Expr, isInline:Bool):Field
    {
        var access:Array<Access> = [Access.APublic, Access.AStatic];
        if (isInline) access.push(Access.AInline);
        return {
            name: name,
            doc: doc,
            access: access,
            kind: FieldType.FVar(null, expr),
            pos: expr.pos
        };
    }
}
#end
