Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Private.Windows.GdiPlus,System.Private.Windows.Core -TypeDefinition @'
using System;
using System.Drawing;
public static class SackBounds {
    public static string Read(string path) {
        using (var image = new Bitmap(path)) {
            int left=image.Width, right=0, top=image.Height, bottom=0;
            for(int y=0;y<image.Height;y++) for(int x=0;x<image.Width;x++) {
                if(image.GetPixel(x,y).A<128) continue;
                left=Math.Min(left,x); right=Math.Max(right,x);
                top=Math.Min(top,y); bottom=Math.Max(bottom,y);
            }
            return String.Format("{0}: Rect2({1}, {2}, {3}, {4})",path,left,top,right-left+1,bottom-top+1);
        }
    }
}
'@
[SackBounds]::Read('D:\Codex\GTA6_Retro_LCD\assets\graphics\sack_dollars.png')
[SackBounds]::Read('D:\Codex\GTA6_Retro_LCD\assets\graphics\sack_contraband.png')
