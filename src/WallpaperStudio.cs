using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

namespace TaskbarMonitorEnhanced
{
    internal static class WallpaperStudio
    {
        internal const int VariantsPerTheme = 10;
        private const int SpiSetDesktopWallpaper = 0x0014;
        private const int SpifUpdateIniFile = 0x01;
        private const int SpifSendWinIniChange = 0x02;

        [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        private static extern bool SystemParametersInfo(int action,int param,string value,int flags);

        internal static int StudioThemeCount { get { return StudioThemes.Create().Length; } }
        internal static int TotalWallpaperCount { get { return StudioThemeCount * VariantsPerTheme; } }
        internal static string[] VariantLabels
        {
            get { return Enumerable.Range(1,VariantsPerTheme).Select(i=>"Wallpaper "+i.ToString("00",CultureInfo.InvariantCulture)).ToArray(); }
        }

        private static int Seed(string text,int variant)
        {
            unchecked
            {
                uint h=2166136261;
                foreach(char c in (text??"")) { h^=c; h*=16777619; }
                h^=(uint)(variant+1)*2654435761u;
                return (int)(h&0x7fffffff);
            }
        }

        private static Color Mix(Color a,Color b,float amount)
        {
            amount=Math.Max(0,Math.Min(1,amount));
            int r=(int)Math.Round(a.R+(b.R-a.R)*amount);
            int g=(int)Math.Round(a.G+(b.G-a.G)*amount);
            int bl=(int)Math.Round(a.B+(b.B-a.B)*amount);
            return Color.FromArgb(255,r,g,bl);
        }

        private static Color Alpha(Color c,int alpha){return Color.FromArgb(Math.Max(0,Math.Min(255,alpha)),c);}

        internal static Bitmap Render(string themeName,int variant,int width,int height)
        {
            if(variant<0||variant>=VariantsPerTheme)throw new ArgumentOutOfRangeException("variant");
            if(width<320||height<180)throw new ArgumentOutOfRangeException("wallpaper dimensions");
            ThemeDefinition t=ThemeCatalog.Get(themeName);
            if(!StudioThemes.IsStudio(t.Mode))throw new InvalidOperationException("Wallpaper Studio is defined for Studio themes only.");

            Bitmap bmp=new Bitmap(width,height,PixelFormat.Format32bppArgb);
            using(Graphics g=Graphics.FromImage(bmp))
            {
                g.SmoothingMode=SmoothingMode.AntiAlias;
                g.CompositingQuality=CompositingQuality.HighQuality;
                g.PixelOffsetMode=PixelOffsetMode.HighQuality;
                Rectangle r=new Rectangle(0,0,width,height);
                float angle=(variant*31+Seed(t.Mode,variant)%29)%180;
                using(var bg=new LinearGradientBrush(r,t.Background,Mix(t.Background2,t.Accents[variant%t.Accents.Length],.16f),angle))
                    g.FillRectangle(bg,r);

                int seed=Seed(t.Name,variant);
                Random rand=new Random(seed);
                Color a=t.Accents[variant%t.Accents.Length];
                Color b=t.Accents[(variant+2)%t.Accents.Length];
                Color c=t.Accents[(variant+4)%t.Accents.Length];

                switch(variant)
                {
                    case 0:
                        using(var p=new Pen(Alpha(a,125),Math.Max(2,width/900f)))
                        for(int i=-height;i<width+height;i+=Math.Max(42,width/24))
                            g.DrawLine(p,i,0,i-height,height);
                        using(var glow=new SolidBrush(Alpha(b,75)))
                            g.FillEllipse(glow,width*.60f,-height*.22f,height*.78f,height*.78f);
                        break;
                    case 1:
                        using(var p=new Pen(Alpha(a,105),Math.Max(1.5f,width/1100f)))
                        {
                            float cx=width*(.20f+(seed%55)/100f),cy=height*(.28f+((seed/7)%38)/100f);
                            for(int i=1;i<=9;i++)
                            {
                                float d=Math.Min(width,height)*(i*.09f);
                                g.DrawEllipse(p,cx-d/2,cy-d/2,d,d);
                            }
                        }
                        break;
                    case 2:
                        for(int i=0;i<9;i++)
                        {
                            float y=height*i/9f;
                            using(var br=new SolidBrush(Alpha(i%2==0?a:b,26+8*i)))
                                g.FillRectangle(br,0,y,width,height/14f);
                        }
                        using(var horizon=new Pen(Alpha(c,170),Math.Max(2,height/420f)))
                            g.DrawLine(horizon,0,height*.63f,width,height*.63f);
                        break;
                    case 3:
                        for(int i=0;i<14;i++)
                        {
                            PointF center=new PointF((float)rand.NextDouble()*width,(float)rand.NextDouble()*height);
                            float s=(float)(Math.Min(width,height)*(.06+.15*rand.NextDouble()));
                            using(var br=new SolidBrush(Alpha(i%3==0?a:i%3==1?b:c,35+rand.Next(45))))
                                g.FillPolygon(br,new[]{new PointF(center.X,center.Y-s),new PointF(center.X+s,center.Y+s*.65f),new PointF(center.X-s,center.Y+s*.65f)});
                        }
                        break;
                    case 4:
                        for(int i=0;i<12;i++)
                        {
                            float x=width*(i+.4f)/12f;
                            float w=width*(.018f+(i%4)*.005f);
                            using(var br=new LinearGradientBrush(new RectangleF(x,0,w,height),Alpha(i%2==0?a:b,120),Color.Transparent,90f))
                                g.FillRectangle(br,x,0,w,height);
                        }
                        break;
                    case 5:
                        using(var p1=new Pen(Alpha(a,145),Math.Max(2,width/1000f)))
                        using(var p2=new Pen(Alpha(b,90),Math.Max(1,width/1300f)))
                        {
                            for(int band=0;band<5;band++)
                            {
                                PointF[] pts=new PointF[33];
                                for(int i=0;i<pts.Length;i++)
                                {
                                    float x=width*i/(pts.Length-1f);
                                    float y=height*(.18f+band*.16f)+(float)Math.Sin(i*.58+band+variant)*height*.045f;
                                    pts[i]=new PointF(x,y);
                                }
                                g.DrawCurve(band%2==0?p1:p2,pts,.55f);
                            }
                        }
                        break;
                    case 6:
                        using(var grid=new Pen(Alpha(a,55),Math.Max(1,width/1800f)))
                        {
                            int step=Math.Max(48,width/20);
                            for(int x=0;x<width;x+=step)g.DrawLine(grid,x,0,x,height);
                            for(int y=0;y<height;y+=step)g.DrawLine(grid,0,y,width,y);
                        }
                        using(var arc=new Pen(Alpha(b,150),Math.Max(2,width/900f)))
                        for(int i=1;i<7;i++)
                        {
                            float d=Math.Min(width,height)*(.12f*i);
                            g.DrawArc(arc,width*.72f-d/2,height*.55f-d/2,d,d,205,255);
                        }
                        break;
                    case 7:
                        using(var p=new Pen(Alpha(a,85),Math.Max(1.5f,width/1200f)))
                        {
                            PointF center=new PointF(width*.50f,height*.52f);
                            for(int i=0;i<42;i++)
                            {
                                double q=Math.PI*2*i/42.0;
                                float len=Math.Min(width,height)*(i%3==0?.52f:.37f);
                                g.DrawLine(p,center,new PointF(center.X+(float)Math.Cos(q)*len,center.Y+(float)Math.Sin(q)*len));
                            }
                        }
                        using(var core=new SolidBrush(Alpha(c,70)))g.FillEllipse(core,width*.39f,height*.31f,width*.22f,height*.39f);
                        break;
                    case 8:
                        using(var line=new Pen(Alpha(c,75),Math.Max(1,width/1800f)))
                        {
                            PointF[] nodes=new PointF[22];
                            for(int i=0;i<nodes.Length;i++)nodes[i]=new PointF((float)rand.NextDouble()*width,(float)rand.NextDouble()*height);
                            for(int i=1;i<nodes.Length;i++)g.DrawLine(line,nodes[i-1],nodes[i]);
                            for(int i=0;i<nodes.Length;i++)
                            {
                                float d=4+(i%5)*2;
                                using(var br=new SolidBrush(Alpha(i%2==0?a:b,130)))g.FillEllipse(br,nodes[i].X-d/2,nodes[i].Y-d/2,d,d);
                            }
                        }
                        break;
                    case 9:
                        using(var frame=new Pen(Alpha(a,155),Math.Max(2,width/800f)))
                        {
                            float m=Math.Min(width,height)*.08f;
                            g.DrawRectangle(frame,m,m,width-2*m,height-2*m);
                            g.DrawLine(frame,m,m,width*.35f,height*.50f);
                            g.DrawLine(frame,width-m,height-m,width*.65f,height*.50f);
                        }
                        using(var wash=new SolidBrush(Alpha(b,38)))g.FillRectangle(wash,width*.10f,height*.15f,width*.36f,height*.70f);
                        break;
                }

                DrawModeSignature(g,t,variant,width,height,a,b,c,seed);
                DrawCornerSignature(g,t,variant,width,height);
            }
            return bmp;
        }

        private static void DrawModeSignature(Graphics g,ThemeDefinition t,int variant,int width,int height,Color a,Color b,Color c,int seed)
        {
            string mode=t.Mode.Substring(7);
            float s=Math.Min(width,height);
            if(mode=="shinobi")
            {
                using(var ink=new Pen(Alpha(t.Foreground,90),Math.Max(5,s*.010f))){ink.StartCap=LineCap.Round;ink.EndCap=LineCap.Round;g.DrawBezier(ink,width*.18f,height*.78f,width*.34f,height*.44f,width*.55f,height*.46f,width*.78f,height*.20f);}
                using(var ember=new Pen(Alpha(a,190),Math.Max(2,s*.004f)))g.DrawArc(ember,width*.62f,height*.12f,s*.30f,s*.30f,18,300);
                using(var sun=new SolidBrush(Alpha(b,48)))g.FillEllipse(sun,width*.66f,height*.16f,s*.22f,s*.22f);
                return;
            }
            if(mode=="bauhaus"||mode=="memphis")
            {
                using(var br=new SolidBrush(Alpha(a,72)))g.FillEllipse(br,width*.08f,height*.68f,s*.18f,s*.18f);
                using(var br=new SolidBrush(Alpha(b,62)))g.FillRectangle(br,width*.75f,height*.15f,s*.15f,s*.15f);
            }
            else if(mode=="circuit"||mode=="scope"||mode=="radar"||mode=="aviation")
            {
                using(var p=new Pen(Alpha(a,105),Math.Max(1.5f,s*.002f)))
                    g.DrawLines(p,new[]{new PointF(width*.08f,height*.17f),new PointF(width*.30f,height*.17f),new PointF(width*.37f,height*.29f),new PointF(width*.68f,height*.29f),new PointF(width*.77f,height*.43f),new PointF(width*.92f,height*.43f)});
            }
            else if(mode=="origami"||mode=="prism"||mode=="stained")
            {
                using(var br=new SolidBrush(Alpha(b,42)))
                    g.FillPolygon(br,new[]{new PointF(width*.53f,height*.08f),new PointF(width*.91f,height*.40f),new PointF(width*.62f,height*.91f),new PointF(width*.25f,height*.58f)});
            }
            else if(mode=="topo"||mode=="kintsugi")
            {
                using(var p=new Pen(Alpha(a,90),Math.Max(1.5f,s*.002f)))
                    for(int i=0;i<5;i++)g.DrawEllipse(p,width*.60f-i*s*.025f,height*.25f-i*s*.018f,s*(.22f+i*.05f),s*(.14f+i*.04f));
            }
        }

        private static void DrawCornerSignature(Graphics g,ThemeDefinition t,int variant,int width,int height)
        {
            int seed=Seed(t.Name+"|"+t.Mode,variant);
            Color mark=Alpha(t.Accents[(variant+3)%t.Accents.Length],85);
            using(var p=new Pen(mark,Math.Max(1,width/1500f)))
            {
                float x=width*.955f,y=height*.92f,unit=Math.Max(3,Math.Min(width,height)/180f);
                for(int bit=0;bit<10;bit++)
                    if(((seed>>bit)&1)!=0)g.DrawLine(p,x-bit*unit,y,x-bit*unit,y-unit*(1+(bit%3)));
            }
        }

        internal static string SafeThemeName(string name)
        {
            StringBuilder b=new StringBuilder();
            foreach(char c in name??"Theme")b.Append(Char.IsLetterOrDigit(c)?c:'_');
            return b.ToString().Trim('_');
        }

        internal static string SuggestedFileName(string themeName,int variant)
        {
            return SafeThemeName(themeName)+"_"+(variant+1).ToString("00",CultureInfo.InvariantCulture)+".png";
        }

        internal static string Materialize(string themeName,int variant,int width,int height)
        {
            string dir=Path.Combine(AppPaths.Root,"Wallpapers",SafeThemeName(themeName));
            Directory.CreateDirectory(dir);
            string path=Path.Combine(dir,SuggestedFileName(themeName,variant));
            using(Bitmap bmp=Render(themeName,variant,width,height))bmp.Save(path,ImageFormat.Png);
            return path;
        }

        private static void RestoreDesktopPreState(string previousPath,string previousStyle,string previousTile)
        {
            try
            {
                using(RegistryKey k=Registry.CurrentUser.OpenSubKey(@"Control Panel\Desktop",true))
                {
                    if(k!=null)
                    {
                        k.SetValue("WallpaperStyle",previousStyle??"",RegistryValueKind.String);
                        k.SetValue("TileWallpaper",previousTile??"",RegistryValueKind.String);
                    }
                }
                if(!String.IsNullOrWhiteSpace(previousPath))
                    SystemParametersInfo(SpiSetDesktopWallpaper,0,previousPath,SpifUpdateIniFile|SpifSendWinIniChange);
            }
            catch{}
        }

        internal static string ApplyDesktop(string themeName,int variant)
        {
            Rectangle bounds=Screen.PrimaryScreen==null?new Rectangle(0,0,1920,1080):Screen.PrimaryScreen.Bounds;
            int width=Math.Max(1920,bounds.Width),height=Math.Max(1080,bounds.Height);
            string path=Materialize(themeName,variant,width,height);
            string dir=Path.GetDirectoryName(path);
            string previousPath="",previousStyle="",previousTile="";
            string backupPath=Path.Combine(dir,"previous-wallpaper-"+DateTime.Now.ToString("yyyyMMdd_HHmmss_fff",CultureInfo.InvariantCulture)+".json");
            try
            {
                using(RegistryKey k=Registry.CurrentUser.OpenSubKey(@"Control Panel\Desktop",false))
                {
                    if(k==null)throw new InvalidOperationException("Desktop registry key unavailable.");
                    previousPath=Convert.ToString(k.GetValue("WallPaper",""),CultureInfo.InvariantCulture)??"";
                    previousStyle=Convert.ToString(k.GetValue("WallpaperStyle",""),CultureInfo.InvariantCulture)??"";
                    previousTile=Convert.ToString(k.GetValue("TileWallpaper",""),CultureInfo.InvariantCulture)??"";
                }
                var prestate=new Dictionary<string,object>{
                    {"CapturedUtc",DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture)},
                    {"WallPaper",previousPath},{"WallpaperStyle",previousStyle},{"TileWallpaper",previousTile}
                };
                File.WriteAllText(backupPath,new JavaScriptSerializer().Serialize(prestate),new UTF8Encoding(false));
            }
            catch(Exception ex){throw new InvalidOperationException("Could not preserve wallpaper pre-state; no desktop change was attempted.",ex);}

            try
            {
                using(RegistryKey k=Registry.CurrentUser.OpenSubKey(@"Control Panel\Desktop",true))
                {
                    if(k==null)throw new InvalidOperationException("Desktop registry key unavailable for update.");
                    k.SetValue("WallpaperStyle","10",RegistryValueKind.String);
                    k.SetValue("TileWallpaper","0",RegistryValueKind.String);
                }
                if(!SystemParametersInfo(SpiSetDesktopWallpaper,0,path,SpifUpdateIniFile|SpifSendWinIniChange))
                    throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(),"Windows rejected desktop wallpaper update.");
                return path;
            }
            catch(Exception ex)
            {
                RestoreDesktopPreState(previousPath,previousStyle,previousTile);
                throw new InvalidOperationException("Desktop wallpaper update failed; prior wallpaper/style restore was attempted. Pre-state: "+backupPath,ex);
            }
        }
    }

    internal sealed class WallpaperPreviewControl : Control
    {
        private string themeName="Art Deco Gold";
        private int variant;
        internal string ThemeName { get { return themeName; } set { themeName=value??"Art Deco Gold"; Invalidate(); } }
        internal int Variant { get { return variant; } set { variant=Math.Max(0,Math.Min(WallpaperStudio.VariantsPerTheme-1,value)); Invalidate(); } }
        internal WallpaperPreviewControl()
        {
            DoubleBuffered=true;Height=225;MinimumSize=new Size(320,180);
            SetStyle(ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer|ControlStyles.UserPaint,true);
        }
        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            Rectangle r=ClientRectangle;if(r.Width<100||r.Height<80)return;
            using(Bitmap bmp=WallpaperStudio.Render(themeName,variant,Math.Max(320,r.Width),Math.Max(180,r.Height)))
                e.Graphics.DrawImage(bmp,r);
            using(var shade=new SolidBrush(Color.FromArgb(125,0,0,0)))e.Graphics.FillRectangle(shade,0,0,r.Width,30);
            using(var title=new Font("Segoe UI Semibold",9f))TextRenderer.DrawText(e.Graphics,themeName+"  /  Wallpaper "+(variant+1).ToString("00",CultureInfo.InvariantCulture),title,new Rectangle(10,5,r.Width-20,22),Color.White,TextFormatFlags.Left|TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis);
            using(var p=new Pen(Color.FromArgb(120,255,255,255)))e.Graphics.DrawRectangle(p,0,0,r.Width-1,r.Height-1);
        }
    }

    internal static class WallpaperStudioProof
    {
        internal static int Run(string outputDirectory)
        {
            try
            {
                Directory.CreateDirectory(outputDirectory);
                const int width=1280,height=720;
                var files=new List<Dictionary<string,object>>();
                var hashes=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                ThemeDefinition[] themes=StudioThemes.Create();
                if(themes.Length!=21)throw new InvalidOperationException("Expected 21 Studio themes.");
                foreach(ThemeDefinition t in themes)
                {
                    for(int v=0;v<WallpaperStudio.VariantsPerTheme;v++)
                    {
                        string dir=Path.Combine(outputDirectory,WallpaperStudio.SafeThemeName(t.Name));Directory.CreateDirectory(dir);
                        string path=Path.Combine(dir,WallpaperStudio.SuggestedFileName(t.Name,v));
                        string hash;
                        using(Bitmap bmp=WallpaperStudio.Render(t.Name,v,width,height))
                        {
                            if(bmp.Width!=width||bmp.Height!=height)throw new InvalidOperationException("Wallpaper dimensions.");
                            bmp.Save(path,ImageFormat.Png);
                        }
                        using(var sha=SHA256.Create())using(var fs=File.OpenRead(path))hash=BitConverter.ToString(sha.ComputeHash(fs)).Replace("-","").ToLowerInvariant();
                        if(!hashes.Add(hash))throw new InvalidOperationException("Duplicate wallpaper pixels: "+t.Name+" #"+(v+1));
                        files.Add(new Dictionary<string,object>{{"Theme",t.Name},{"Variant",v+1},{"File",Path.GetFileName(path)},{"SHA256",hash},{"Bytes",new FileInfo(path).Length}});
                    }
                }
                if(files.Count!=210||hashes.Count!=210)throw new InvalidOperationException("Wallpaper count.");
                var manifest=new Dictionary<string,object>{{"Status","PASS"},{"ThemeCount",themes.Length},{"VariantsPerTheme",WallpaperStudio.VariantsPerTheme},{"WallpaperCount",files.Count},{"UniquePixelFiles",hashes.Count},{"Width",width},{"Height",height},{"GeneratedUtc",DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture)},{"Files",files}};
                File.WriteAllText(Path.Combine(outputDirectory,"WALLPAPER_PROOF_MANIFEST.json"),new JavaScriptSerializer().Serialize(manifest),new UTF8Encoding(false));
                Console.WriteLine("TBME_WALLPAPER_PROOF=PASS THEMES="+themes.Length+" VARIANTS=10 WALLPAPERS="+files.Count+" UNIQUE="+hashes.Count+" DIR="+outputDirectory);
                return 0;
            }
            catch(Exception ex)
            {
                Console.Error.WriteLine("TBME_WALLPAPER_PROOF=FAIL "+ex);
                return 31;
            }
        }
    }
}
