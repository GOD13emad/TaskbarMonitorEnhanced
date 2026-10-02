// Original theme designs for TBME v1.6.0. No downloaded skins, fonts or executable plugins.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Linq;

namespace TaskbarMonitorEnhanced
{
    internal static class StudioThemes
    {
        private static Color C(int rgb) { return Color.FromArgb((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255); }
        private static ThemeDefinition T(string name, string mode, int bg, int panel, int fg, int muted, int border, bool light, params int[] accents)
        { return new ThemeDefinition(name, C(bg), C(panel), C(fg), C(muted), C(border), accents.Select(C).ToArray(), "studio-" + mode, mode == "lcd" || mode == "scope" || mode == "dots" ? "Consolas" : "Segoe UI", light); }
        internal static ThemeDefinition[] Create()
        {
            return new[] {
                T("Bauhaus Blocks", "bauhaus", 0xF3EBD9,0xFFFAED,0x191C21,0x505252,0x303237,true,0xA82620,0x244CA3,0x946800,0x176954,0x864070,0x185F7D),
                T("Swiss Grid", "swiss", 0xFFFFFF,0xF1F3F5,0x16191E,0x565D67,0xB5BDC6,true,0xC62132,0x294F8D,0x197349,0x855800,0x763FA2,0x076979),
                T("Art Deco Gold", "deco", 0x101B20,0x172A30,0xFFF2CB,0xCEBF94,0x8D794C,false,0xF2CE73,0x7AD3BF,0xCCB4FF,0xF2AA83,0x8BC7F6,0xE2E9AF),
                T("E Ink Ledger", "ledger", 0xECEEE7,0xFAFBF6,0x232721,0x50564C,0x939C8B,true,0x3C4837,0x535E42,0x3D585B,0x635344,0x554969,0x414C65),
                T("Noir Cinema", "cinema", 0x08090B,0x1C1C22,0xF1EAE4,0xB3ABA9,0x635C64,false,0xE6AD93,0xD4C1FA,0xC0DAC8,0xE6D39E,0xBCDAEC,0xEDB1C4),
                T("Metro Signal", "metro", 0x12172B,0x202640,0xFAFCFF,0xB2BCD7,0x55618A,false,0xFD9D54,0x7AB1FF,0x80E5AA,0xF8D966,0xDC9FF3,0x76E0E5),
                T("LCD Quartz", "lcd", 0xC4D3A1,0xDFE7C1,0x25351A,0x435333,0x71845A,true,0x334B24,0x315C48,0x495127,0x4D3E2B,0x254C51,0x43425D),
                T("Oscilloscope Phosphor", "scope", 0x07100D,0x0C211B,0xC5FFDE,0x88BBA3,0x357660,false,0x6AFBB0,0x99F4E4,0xCEF790,0xF8D886,0x9AC8F2,0xDEADE6),
                T("Radar Vector", "radar", 0x0F1B10,0x1B2C19,0xE5F4C8,0xA9BF92,0x668056,false,0xC1ED79,0x7CDBBF,0xF7D275,0xB7C9F0,0xF4AF8E,0xD8B5F0),
                T("Aviation HUD", "aviation", 0x0A1825,0x172A3B,0xE9F9FF,0x9DBFD4,0x4E839B,false,0x81EAF9,0xAAD4FF,0xCDEB8A,0xFFDA8A,0xFCADAA,0xDDC5FF),
                T("Isometric Prism", "prism", 0x201634,0x352348,0xFFF1FF,0xCBADD9,0x90669D,false,0xF5A0DA,0xAEBAFF,0x85E7E1,0xFCD485,0xB6E899,0xFFAC91),
                T("Ribbon Flow", "ribbon", 0xFFF5EF,0xFFE6DB,0x412A31,0x805964,0xBA8C99,true,0xAE345A,0x53559F,0x287965,0x9A641E,0x994776,0x226B89),
                T("Circuit Trace", "circuit", 0x081F22,0x103138,0xDBFEF4,0x93C8BF,0x427F7A,false,0x68E9BA,0xEAC56C,0x83CFFA,0xDEA5F3,0xFAAD8A,0xC9ED98),
                T("Dot Matrix", "dots", 0x171012,0x2D2023,0xFFE3CD,0xCBAA97,0x856451,false,0xFFC487,0xE7A9B8,0xF9DE8E,0xAFCB8C,0xA5CDE0,0xD3B5ED),
                T("Topographic Moss", "topo", 0xE8ECDF,0xF5F7EB,0x273C32,0x526D5B,0x93AB91,true,0x2C7650,0x506787,0x8B632D,0x9A4F4D,0x6C5588,0x237080),
                T("Memphis Pop", "memphis", 0xFFF1CE,0xFFF9E9,0x30273F,0x665D74,0xA598AD,true,0xB32E68,0x3659B1,0x197D73,0xA65B19,0x794B9D,0x30784F),
                T("Origami Snow", "origami", 0xE6EDF4,0xFAFDFF,0x26334E,0x556782,0x98ACC7,true,0x37649F,0x8E478F,0x237A6E,0x906623,0xAD4B4D,0x525DA5),
                T("Kintsugi Ink", "kintsugi", 0x171619,0x29252A,0xF5EDDF,0xC0B5A4,0x8C7B5B,false,0xEDC271,0xDDA5AA,0x9DC4CA,0xB7CF9E,0xC0AEEE,0xEAAF89),
                T("Brutalist Concrete", "brutal", 0xDAD9D4,0xF5F4ED,0x171918,0x4F5450,0x282D2A,true,0x9F2A1D,0x254AA0,0x21704C,0x845600,0x733A80,0x006C77),
                T("Stained Glass", "stained", 0x191629,0x2C2944,0xFFF4EF,0xC7B9D4,0x8E77A4,false,0xF5A597,0x9CC8F5,0x9DDBB1,0xF3D28D,0xD8ABEC,0x8FDFDC)
            };
        }
        internal static bool IsStudio(string mode) { return mode != null && mode.StartsWith("studio-", StringComparison.Ordinal); }
    }

    internal sealed partial class OverlayForm
    {
        // Geometry is deliberately distinct, static and deterministic. No animation timer or bitmap assets.
        private void PaintStudioBackground(Graphics g, ThemeDefinition t, Rectangle r)
        {
            if(r.Width < 2 || r.Height < 2) return;
            string mode = t.Mode.Substring(7);
            using(var b = new LinearGradientBrush(r,t.Background,t.Background2, mode=="ribbon"?0f:90f)) g.FillRectangle(b,r);
            using(var p = new Pen(Color.FromArgb(28,t.Accents[0]),1))
            {
                if(mode=="scope" || mode=="swiss") {
                    for(int x=0;x<r.Width;x+=24) g.DrawLine(p,x,0,x,r.Height);
                    for(int y=0;y<r.Height;y+=12) g.DrawLine(p,0,y,r.Width,y);
                } else if(mode=="topo") {
                    for(int x=-60;x<r.Width;x+=92) for(int k=0;k<3;k++) g.DrawEllipse(p,x-k*8,10-k*9,65+k*16,40+k*18);
                } else if(mode=="circuit") {
                    for(int x=0;x<r.Width;x+=64) { g.DrawLines(p,new[]{new Point(x,5),new Point(x+18,5),new Point(x+28,15),new Point(x+55,15)}); g.DrawEllipse(p,x+54,12,5,5); }
                } else if(mode=="stained" || mode=="prism") {
                    for(int x=0;x<r.Width;x+=56) g.DrawPolygon(p,new[]{new Point(x,0),new Point(x+28,r.Height),new Point(x+56,0)});
                }
            }
        }
        private void PaintStudioMetric(Graphics g, ThemeDefinition t, MetricView m, RectangleF r, Font labelFont, Font valueFont)
        {
            if(r.Width<12 || r.Height<12) return;
            GraphicsState saved=g.Save();
            try {
                g.SetClip(r,CombineMode.Intersect);
                string mode=t.Mode.Substring(7);
                float x=r.X, y=r.Y, w=r.Width-1, h=r.Height-1;
                Color accent=m.Alert?AlertPolicy.AlertColor:m.Accent;
                using(var fill=new SolidBrush(t.Background2))
                using(var faint=new SolidBrush(Color.FromArgb(35,accent)))
                using(var mark=new SolidBrush(accent))
                using(var edge=new Pen(t.Border,1))
                using(var line=new Pen(accent,1.4f))
                {
                    switch(mode) {
                        case "bauhaus":
                            g.FillRectangle(fill,x,y,w,h);g.FillRectangle(mark,x,y,4,h);g.FillEllipse(faint,x+w-28,y-12,38,38);g.DrawLine(edge,x+7,y+h,w+x,y+h);break;
                        case "swiss":
                            g.FillRectangle(fill,x,y,w,h);g.FillRectangle(mark,x,y,24,2);g.DrawLine(edge,x,y+h,x+w,y+h);g.DrawLine(edge,x+w-1,y,x+w-1,y+h);break;
                        case "deco":
                            g.FillRectangle(fill,x+2,y+2,w-4,h-4);g.DrawRectangle(line,x+1,y+1,w-2,h-2);g.DrawRectangle(edge,x+4,y+4,w-8,h-8);
                            g.DrawLines(line,new[]{new PointF(x+2,y+12),new PointF(x+2,y+2),new PointF(x+12,y+2)});break;
                        case "ledger":
                            g.FillRectangle(fill,x,y,w,h);for(float ly=y+15;ly<y+h;ly+=12) g.DrawLine(edge,x,ly,x+w,ly);g.DrawLine(line,x+4,y,x+4,y+h);break;
                        case "cinema":
                            g.FillRectangle(fill,x+5,y,w-10,h);for(float yy=y+3;yy<y+h;yy+=8){g.FillRectangle(faint,x,yy,3,4);g.FillRectangle(faint,x+w-3,yy,3,4);}break;
                        case "metro":
                            g.FillRectangle(fill,x,y,w,h);g.FillRectangle(mark,x,y,5,h);g.FillRectangle(faint,x+5,y+h-6,w-5,6);g.DrawLine(edge,x+5,y,x+w,y);break;
                        case "lcd":
                            g.FillRectangle(fill,x,y,w,h);g.DrawRectangle(edge,x+1,y+1,w-2,h-2);g.DrawRectangle(edge,x+3,y+3,w-6,h-6);break;
                        case "scope":
                            g.DrawRectangle(edge,x,y,w,h);g.DrawLine(line,x,y+8,x+4,y+8);g.DrawLine(line,x,y+h-8,x+4,y+h-8);break;
                        case "radar":
                            g.FillRectangle(fill,x,y,w,h);for(int k=1;k<=3;k++)g.DrawArc(edge,x+w-28-k*5,y+h-20-k*5,20+k*10,20+k*10,190,150);g.DrawLine(line,x+w-17,y+h-7,x+w-4,y+h-20);break;
                        case "aviation":
                            g.FillRectangle(fill,x+4,y+1,w-8,h-2);g.DrawLines(line,new[]{new PointF(x+9,y),new PointF(x,y),new PointF(x,y+9)});
                            g.DrawLines(line,new[]{new PointF(x+w-9,y+h),new PointF(x+w,y+h),new PointF(x+w,y+h-9)});g.DrawLine(edge,x+w/2-7,y+h-3,x+w/2+7,y+h-3);break;
                        case "prism":
                            g.FillPolygon(fill,new[]{new PointF(x+6,y),new PointF(x+w,y),new PointF(x+w-6,y+h),new PointF(x,y+h)});
                            g.FillPolygon(faint,new[]{new PointF(x+w-26,y),new PointF(x+w,y),new PointF(x+w-6,y+h)});g.DrawLine(line,x+6,y,x+w,y);break;
                        case "ribbon":
                            g.FillRectangle(fill,x+2,y+2,w-4,h-4);g.FillRectangle(faint,x,y,w,12);g.FillPolygon(mark,new[]{new PointF(x,y),new PointF(x+5,y+5),new PointF(x,y+10)});break;
                        case "circuit":
                            g.FillRectangle(fill,x+2,y+2,w-4,h-4);g.DrawRectangle(edge,x+2,y+2,w-4,h-4);
                            for(int k=0;k<3;k++) {g.DrawLine(line,x+12+k*7,y,x+12+k*7,y+3);g.DrawLine(line,x+w-12-k*7,y+h-3,x+w-12-k*7,y+h);}break;
                        case "dots":
                            g.FillRectangle(fill,x,y,w,h);for(float xx=x+3;xx<x+w;xx+=5){g.FillEllipse(faint,xx,y,2,2);g.FillEllipse(faint,xx,y+h-2,2,2);}break;
                        case "topo":
                            using(var path=RoundRect(new RectangleF(x,y,w,h),Math.Min(8,h/3))) {g.FillPath(fill,path);g.DrawPath(edge,path);}g.DrawArc(line,x+3,y+3,7,7,20,280);break;
                        case "memphis":
                            g.FillRectangle(fill,x+2,y+2,w-4,h-4);g.DrawRectangle(edge,x+2,y+2,w-4,h-4);
                            g.FillPolygon(mark,new[]{new PointF(x+w-10,y+1),new PointF(x+w-1,y+1),new PointF(x+w-1,y+10)});g.DrawEllipse(line,x+2,y+h-8,7,7);break;
                        case "origami":
                            g.FillPolygon(fill,new[]{new PointF(x,y),new PointF(x+w-10,y),new PointF(x+w,y+10),new PointF(x+w,y+h),new PointF(x,y+h)});
                            g.FillPolygon(faint,new[]{new PointF(x+w-10,y),new PointF(x+w-10,y+10),new PointF(x+w,y+10)});g.DrawLine(edge,x,y+h,x+w,y+h);break;
                        case "kintsugi":
                            g.FillRectangle(fill,x,y,w,h);g.DrawLines(line,new[]{new PointF(x+w-4,y),new PointF(x+w-8,y+9),new PointF(x+w-3,y+18),new PointF(x+w-7,y+h)});break;
                        case "brutal":
                            g.FillRectangle(mark,x+3,y+3,w-3,h-3);g.FillRectangle(fill,x,y,w-3,h-3);using(var bold=new Pen(t.Foreground,2))g.DrawRectangle(bold,x+1,y+1,w-5,h-5);break;
                        case "stained":
                            g.FillRectangle(fill,x,y,w,h);g.FillPolygon(faint,new[]{new PointF(x+w-26,y),new PointF(x+w,y+12),new PointF(x+w-4,y+h)});
                            g.DrawLines(edge,new[]{new PointF(x+w-26,y),new PointF(x+w-4,y+h),new PointF(x+w,y+h/2)});g.DrawRectangle(edge,x,y,w,h);break;
                    }
                }
                // Text keeps the established responsive headline/unit policy. Decorative geometry cannot overflow a tile.
                float textX=x+9, textWidth=Math.Max(8,w-19);
                string headline=BuildMetricHeadline(g,t,m,7.4f,textWidth);
                using(Font f=FitHeadlineFont(g,t.FontName,headline,8.7f,7.4f,textWidth))
                using(var b=new SolidBrush(t.Foreground))g.DrawString(headline,f,b,new PointF(textX,y+4));
                bool stacked=HeadlineIsStacked(headline);
                RectangleF graph=new RectangleF(x+9,y+(stacked?30:24),Math.Max(4,w-18),Math.Max(4,h-(stacked?34:28)));
                if(!config.ShowSparklines)return;
                if(mode=="lcd" || mode=="dots") {
                    if(m.History==null||m.History.Count==0)return;
                    int count=Math.Min(24,m.History.Count);float max=Math.Max(1,m.History.Skip(m.History.Count-count).Max());float dx=graph.Width/count;
                    using(var b=new SolidBrush(accent))for(int i=0;i<count;i++){float v=m.History[m.History.Count-count+i]/max;int levels=Math.Max(1,(int)Math.Round(v*3));for(int k=0;k<levels;k++) {if(mode=="dots")g.FillEllipse(b,graph.X+i*dx,graph.Bottom-2-k*3,Math.Max(1,Math.Min(2,dx-1)),2);else g.FillRectangle(b,graph.X+i*dx,graph.Bottom-2-k*3,Math.Max(1,dx-1),2);}}
                } else if(mode=="bauhaus" || mode=="metro" || mode=="brutal")DrawMissionBars(g,m.History,graph,accent);
                else DrawSparkline(g,m.History,graph,accent,mode=="scope"?1.6f:1.25f,mode=="scope" || mode=="prism");
            } finally {g.Restore(saved);}
        }
    }
}
