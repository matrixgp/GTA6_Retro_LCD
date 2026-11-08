Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Private.Windows.GdiPlus,System.Private.Windows.Core -TypeDefinition @'
using System;
using System.Drawing;
public static class RailCheck {
    static bool Ink(Color c) { return c.R < 85 && c.G < 105 && c.B < 85; }
    public static string Check(string original, string edited) {
        using (var a = new Bitmap(original)) using (var b = new Bitmap(edited)) {
            if (a.Size != b.Size) return "SIZE MISMATCH";
            var rects = new [] {new Rectangle(445,395,205,85),new Rectangle(445,535,205,80),new Rectangle(920,395,210,90),new Rectangle(920,530,210,85)};
            string output = "";
            foreach (var r in rects) {
                int best = int.MaxValue, bestX = 0, bestY = 0, unshifted = 0;
                for (int dy=-5;dy<=5;dy++) for(int dx=-5;dx<=5;dx++) {
                    int error=0;
                    for(int y=r.Top;y<r.Bottom;y+=2) for(int x=r.Left;x<r.Right;x+=2)
                        if (Ink(a.GetPixel(x,y)) != Ink(b.GetPixel(x+dx,y+dy))) error++;
                    if(dx==0 && dy==0) unshifted=error;
                    if(error<best) {best=error; bestX=dx; bestY=dy;}
                }
                output += String.Format("Rail {0}: best shift ({1},{2}), mismatch {3}, original-position mismatch {4}\n",r,bestX,bestY,best,unshifted);
            }
            return output;
        }
    }
}
'@
[RailCheck]::Check('D:\Codex\GTA6_Retro_LCD\assets\graphics\retro_device.png', 'D:\Codex\GTA6_Retro_LCD\assets\graphics\retro_device_clean.png')
