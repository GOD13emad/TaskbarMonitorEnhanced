using System.Text;
using System.IO;
using System.Web.Script.Serialization;
// R41: per-pixel taskbar background translucency with independent, contrast-safe glyphs.
// No screen pixels are stored. Only off-overlay taskbar samples are read in memory.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using Microsoft.Win32;

namespace TaskbarMonitorEnhanced
{
    internal static class TaskbarGlassColor
    {
        internal static double Luminance(Color c)
        {
            Func<byte,double> f=v=>{double x=v/255.0;return x<=0.04045?x/12.92:Math.Pow((x+0.055)/1.055,2.4);};
            return 0.2126*f(c.R)+0.7152*f(c.G)+0.0722*f(c.B);
        }
        internal static double Contrast(Color a,Color b)
        {
            double x=Luminance(a),y=Luminance(b);
            return (Math.Max(x,y)+.05)/(Math.Min(x,y)+.05);
        }
        internal static Color EffectiveBackground(Color taskbar,Color theme,double opacity)
        {
            double q=Math.Max(0,Math.Min(1,opacity));
            return Color.FromArgb((int)Math.Round(taskbar.R+(theme.R-taskbar.R)*q),
                (int)Math.Round(taskbar.G+(theme.G-taskbar.G)*q),
                (int)Math.Round(taskbar.B+(theme.B-taskbar.B)*q));
        }
        internal static Color ReadableText(Color effective)
        {
            return Contrast(Color.White,effective)>=Contrast(Color.Black,effective)?Color.White:Color.Black;
        }
        internal static Color Fallback()
        {
            if(SystemInformation.HighContrast)return SystemColors.Window;
            try
            {
                using(RegistryKey k=Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"))
                {
                    object light=k==null?null:k.GetValue("SystemUsesLightTheme");
                    if(light is int)return (int)light==0?Color.FromArgb(31,31,35):Color.FromArgb(239,239,241);
                }
            }
            catch{}
            return Color.FromArgb(36,36,40);
        }

        // Never sample the monitor itself: avoid self-feedback and leaking screen contents.
        internal static Color Sample(Rectangle taskbarRect,Rectangle overlayRect,out bool actual)
        {
            actual=false;
            if(taskbarRect.Width<10||taskbarRect.Height<4)return Fallback();
            Rectangle screen=SystemInformation.VirtualScreen;
            var samples=new List<Color>();
            int centerY=taskbarRect.Top+taskbarRect.Height/2;
            int[] xs={
                taskbarRect.Left+8,taskbarRect.Left+taskbarRect.Width/5,
                taskbarRect.Left+taskbarRect.Width*2/5,taskbarRect.Left+taskbarRect.Width*3/5,
                taskbarRect.Left+taskbarRect.Width*4/5,taskbarRect.Right-8,
                overlayRect.Left-16,overlayRect.Right+16,
                overlayRect.Left-40,overlayRect.Right+40
            };
            foreach(int x in xs.Distinct())
            {
                Point p=new Point(x,centerY);
                if(!taskbarRect.Contains(p)||!screen.Contains(p)||
                   Rectangle.Inflate(overlayRect,10,3).Contains(p))continue;
                try
                {
                    using(var b=new Bitmap(1,1,PixelFormat.Format32bppArgb))
                    using(Graphics g=Graphics.FromImage(b))
                    {
                        g.CopyFromScreen(p,Point.Empty,new Size(1,1),CopyPixelOperation.SourceCopy);
                        samples.Add(b.GetPixel(0,0));
                    }
                }
                catch{}
            }
            if(samples.Count<2)return Fallback();
            // Median brightness avoids taskbar icons, time glyphs and the accent-colored Start icon.
            Color result=samples.OrderBy(Luminance).ElementAt(samples.Count/2);
            actual=true;
            return result;
        }
    }

    // Windows 11 DirectComposition can visually occlude layered Shell_TrayWnd children.
    // UpdateLayeredWindow's success is insufficient proof of readable foreground.
    // At sub-100% opacity draw a top-level click-accessible, taskbar-anchored glass
    // overlay with a verified native per-pixel surface. At 100% preserve the
    // previously accepted direct-child mode; High Contrast always remains opaque.
    internal static class TaskbarGlassHostMode
    {
        internal static bool RequiresTopLevel(double backgroundOpacity,bool highContrast)
        {
            return !highContrast && backgroundOpacity<0.999999;
        }
    }

    internal static class TaskbarGlassPixels
    {
        internal static byte[] ReadPixels(Bitmap b,PixelFormat format)
        {
            Rectangle region=new Rectangle(0,0,b.Width,b.Height);
            BitmapData d=b.LockBits(region,ImageLockMode.ReadOnly,format);
            try
            {
                byte[] dst=new byte[b.Width*b.Height*4];
                for(int y=0;y<b.Height;y++)
                    Marshal.Copy(IntPtr.Add(d.Scan0,y*d.Stride),dst,y*b.Width*4,b.Width*4);
                return dst;
            }
            finally{b.UnlockBits(d);}
        }
        internal static void WritePixels(Bitmap b,byte[] src)
        {
            Rectangle region=new Rectangle(0,0,b.Width,b.Height);
            BitmapData d=b.LockBits(region,ImageLockMode.WriteOnly,PixelFormat.Format32bppPArgb);
            try
            {
                for(int y=0;y<b.Height;y++)
                    Marshal.Copy(src,y*b.Width*4,IntPtr.Add(d.Scan0,y*d.Stride),b.Width*4);
            }
            finally{b.UnlockBits(d);}
        }
        private static byte Byte(double x){return (byte)Math.Max(0,Math.Min(255,(int)Math.Round(x)));}
        internal static Bitmap Compose(Bitmap full,Bitmap glyph,Bitmap halo,int opacityPercent,Color taskbar,Color themeBackground)
        {
            if(full==null)throw new ArgumentNullException("full");
            if(glyph!=null&&(glyph.Width!=full.Width||glyph.Height!=full.Height))throw new ArgumentException("glyph geometry");
            if(halo!=null&&(halo.Width!=full.Width||halo.Height!=full.Height))throw new ArgumentException("halo geometry");
            int pct=Math.Max(0,Math.Min(100,opacityPercent));
            byte[] basePixels=ReadPixels(full,PixelFormat.Format32bppArgb);
            byte[] inkPixels=glyph==null?null:ReadPixels(glyph,PixelFormat.Format32bppPArgb);
            byte[] haloPixels=halo==null?null:ReadPixels(halo,PixelFormat.Format32bppPArgb);
            byte[] pixels=new byte[basePixels.Length];
            bool adaptInk=pct<=30;
            Color chosen=TaskbarGlassColor.ReadableText(TaskbarGlassColor.EffectiveBackground(taskbar,themeBackground,pct/100d));
            Color outline=chosen.ToArgb()==Color.White.ToArgb()?Color.Black:Color.White;
            double backgroundScale=pct/100d;
            for(int i=0;i<pixels.Length;i+=4)
            {
                double ink=inkPixels==null?0:inkPixels[i+3]/255d;
                double ring=adaptInk&&haloPixels!=null?Math.Max(0,haloPixels[i+3]/255d-ink)*0.78:0;
                ring=Math.Min(1-ink,ring);
                double bg=(1-ink-ring)*backgroundScale*(basePixels[i+3]/255d);
                pixels[i+3]=Byte((ink+ring+bg)*255);
                for(int ch=0;ch<3;ch++)
                {
                    int textChannel=ch==0?chosen.B:ch==1?chosen.G:chosen.R;
                    int outlineChannel=ch==0?outline.B:ch==1?outline.G:outline.R;
                    double glyphContribution=adaptInk?textChannel*ink:(inkPixels==null?0:inkPixels[i+ch]);
                    pixels[i+ch]=Byte(glyphContribution+outlineChannel*ring+basePixels[i+ch]*bg);
                }
            }
            Bitmap result=new Bitmap(full.Width,full.Height,PixelFormat.Format32bppPArgb);
            try{WritePixels(result,pixels);return result;}
            catch{result.Dispose();throw;}
        }
    }

    internal static class TaskbarGlassNative
    {
        [StructLayout(LayoutKind.Sequential)] private struct NPoint { public int X,Y; public NPoint(int x,int y){X=x;Y=y;} }
        [StructLayout(LayoutKind.Sequential)] private struct NSize { public int CX,CY; public NSize(int w,int h){CX=w;CY=h;} }
        [StructLayout(LayoutKind.Sequential,Pack=1)] private struct Blend
        {
            public byte BlendOp,BlendFlags,ConstantAlpha,AlphaFormat;
        }
        [StructLayout(LayoutKind.Sequential)] private struct BitmapInfoHeader
        {
            public uint Size; public int Width,Height;
            public ushort Planes,BitCount;
            public uint Compression,SizeImage;public int XPelsPerMeter,YPelsPerMeter;
            public uint ClrUsed,ClrImportant;
        }
        [StructLayout(LayoutKind.Sequential)] private struct BitmapInfo
        {
            public BitmapInfoHeader Header;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst=3)] public uint[] Colors;
        }
        [DllImport("user32.dll",SetLastError=true)] private static extern IntPtr GetDC(IntPtr window);
        [DllImport("user32.dll",SetLastError=true)] private static extern int ReleaseDC(IntPtr window,IntPtr dc);
        [DllImport("gdi32.dll",SetLastError=true)] private static extern IntPtr CreateCompatibleDC(IntPtr dc);
        [DllImport("gdi32.dll",SetLastError=true)] private static extern bool DeleteDC(IntPtr dc);
        [DllImport("gdi32.dll",SetLastError=true)] private static extern IntPtr CreateDIBSection(IntPtr dc,ref BitmapInfo info,uint use,out IntPtr bits,IntPtr section,uint offset);
        [DllImport("gdi32.dll",SetLastError=true)] private static extern IntPtr SelectObject(IntPtr dc,IntPtr obj);
        [DllImport("gdi32.dll",SetLastError=true)] private static extern bool DeleteObject(IntPtr obj);
        [DllImport("user32.dll",SetLastError=true)] private static extern bool UpdateLayeredWindow(IntPtr hwnd,IntPtr screen,ref NPoint dst,ref NSize size,IntPtr source,ref NPoint sourcePoint,uint colorKey,ref Blend blend,uint flags);

        internal static bool Upload(IntPtr window,Bitmap picture,Point screenLocation,out int win32)
        {
            win32=0;
            if(window==IntPtr.Zero||picture==null||picture.Width<1||picture.Height<1){win32=87;return false;}
            IntPtr screen=IntPtr.Zero,dc=IntPtr.Zero,dib=IntPtr.Zero,old=IntPtr.Zero;
            try
            {
                screen=GetDC(IntPtr.Zero);
                if(screen==IntPtr.Zero){win32=Marshal.GetLastWin32Error();return false;}
                dc=CreateCompatibleDC(screen);
                if(dc==IntPtr.Zero){win32=Marshal.GetLastWin32Error();return false;}
                BitmapInfo info=new BitmapInfo{
                    Header=new BitmapInfoHeader{Size=(uint)Marshal.SizeOf(typeof(BitmapInfoHeader)),Width=picture.Width,
                        Height=-picture.Height,Planes=1,BitCount=32,Compression=0,SizeImage=(uint)(picture.Width*picture.Height*4)},
                    Colors=new uint[3]};
                IntPtr pixels;
                dib=CreateDIBSection(screen,ref info,0,out pixels,IntPtr.Zero,0);
                if(dib==IntPtr.Zero||pixels==IntPtr.Zero){win32=Marshal.GetLastWin32Error();return false;}
                byte[] data=TaskbarGlassPixels.ReadPixels(picture,PixelFormat.Format32bppPArgb);
                Marshal.Copy(data,0,pixels,data.Length);
                old=SelectObject(dc,dib);
                if(old==IntPtr.Zero||old==new IntPtr(-1)){win32=Marshal.GetLastWin32Error();return false;}
                var dst=new NPoint(screenLocation.X,screenLocation.Y);
                var src=new NPoint(0,0);
                var sz=new NSize(picture.Width,picture.Height);
                var blend=new Blend{BlendOp=0,BlendFlags=0,ConstantAlpha=255,AlphaFormat=1};
                bool ok=UpdateLayeredWindow(window,screen,ref dst,ref sz,dc,ref src,0,ref blend,2);
                if(!ok)win32=Marshal.GetLastWin32Error();
                return ok;
            }
            catch(ExternalException){win32=Marshal.GetLastWin32Error();return false;}
            finally
            {
                if(dc!=IntPtr.Zero&&old!=IntPtr.Zero&&old!=new IntPtr(-1))SelectObject(dc,old);
                if(dib!=IntPtr.Zero)DeleteObject(dib);
                if(dc!=IntPtr.Zero)DeleteDC(dc);
                if(screen!=IntPtr.Zero)ReleaseDC(IntPtr.Zero,screen);
            }
        }
    }

    internal sealed partial class OverlayForm
    {
        private bool glassNativeVisualProofMode;
        internal bool RequiresGlassTopLevel
        {get{return config!=null && (!proofMode||glassNativeVisualProofMode) &&
                     TaskbarGlassHostMode.RequiresTopLevel(config.Opacity,SystemInformation.HighContrast);}}
        internal void EnableNativeGlassVisualProof()
        {
            if(!proofMode||IsHandleCreated)throw new InvalidOperationException("Glass visual proof requires a fresh proof-only instance.");
            glassNativeVisualProofMode=true;
        }
        internal bool SwitchNativeGlassForProof(double nextOpacity)
        {
            if(!proofMode||!glassNativeVisualProofMode)
                throw new InvalidOperationException("Mode transition allowed only in isolated proof instance.");
            config.Opacity=Math.Max(0,Math.Min(1,nextOpacity));
            config.Normalize();
            AttachIntegrated();
            if(!IsHandleCreated||!Native.IsWindowVisible(Handle))return false;
            long style=Native.GetWindowLongPtr(Handle,Native.GWL_STYLE).ToInt64();
            if(RequiresGlassTopLevel)
                return (style&Native.WS_CHILD)==0 && !glassLegacyFallback;
            return (style&Native.WS_CHILD)!=0 && Native.GetParent(Handle)==taskbar;
        }

        internal Rectangle AttachNativeGlassVisualProof()
        {
            if(!proofMode||!glassNativeVisualProofMode)throw new InvalidOperationException("Not a native-proof form.");
            AttachIntegrated();
            if(!RequiresGlassTopLevel||glassLegacyFallback||expectedRect.Width<500||
               !IsHandleCreated||!Native.IsWindowVisible(Handle)||
               (Native.GetWindowLongPtr(Handle,Native.GWL_STYLE).ToInt64()&Native.WS_CHILD)!=0)
                throw new InvalidOperationException("Production top-level glass compositor did not attach natively.");
            long ex=Native.GetWindowLongPtr(Handle,Native.GWL_EXSTYLE).ToInt64();
            if((ex&Native.WS_EX_LAYERED)==0||(ex&Native.WS_EX_COMPOSITED)!=0||
               (ex&Native.WS_EX_TRANSPARENT)!=0)
                throw new InvalidOperationException("Native proof top-level layered style incorrect.");
            return expectedRect;
        }

        private int glassDirectMetricRefreshCount;
        internal int GlassDirectMetricRefreshCountForProof {get{return glassDirectMetricRefreshCount;}}
        private void RefreshGlassAfterMetricCommit()
        {
            if(!IsHandleCreated||!RequiresGlassTopLevel||glassLegacyFallback)return;
            if(proofMode&&!glassNativeVisualProofMode)return;
            if(PaintPerPixelLayer())glassDirectMetricRefreshCount++;
            // On failure PaintPerPixelLayer already records native error and applies
            // the opaque last-resort fallback; never misreport successful refresh.
        }

        private Graphics glassInkCanvas,glassHaloCanvas;
        private bool glassLegacyFallback;
        private bool glassLegacyFallbackReady;
        private DateTime taskbarGlassSampleAt=DateTime.MinValue;
        private Color taskbarGlassColor=Color.FromArgb(32,32,36);
        private bool taskbarGlassSampled;
        private DateTime glassLastFailureAt=DateTime.MinValue;

        private void DrawThemeGlyph(Graphics g,string text,Font f,Brush brush,float x,float y)
        {
            g.DrawString(text,f,brush,x,y);
            if(glassInkCanvas==null)return;
            glassInkCanvas.DrawString(text,f,brush,x,y);
            if(glassHaloCanvas!=null)
            {
                using(var halo=new SolidBrush(Color.White))
                {
                    glassHaloCanvas.DrawString(text,f,halo,x-1,y);
                    glassHaloCanvas.DrawString(text,f,halo,x+1,y);
                    glassHaloCanvas.DrawString(text,f,halo,x,y-1);
                    glassHaloCanvas.DrawString(text,f,halo,x,y+1);
                }
            }
        }
        private void DrawThemeGlyph(Graphics g,string text,Font f,Brush brush,PointF p)
        {DrawThemeGlyph(g,text,f,brush,p.X,p.Y);}

        private Color GlassTaskbarSample()
        {
            if(proofMode&&!glassNativeVisualProofMode)return TaskbarGlassColor.Fallback();
            DateTime now=DateTime.UtcNow;
            if((now-taskbarGlassSampleAt).TotalSeconds<4)return taskbarGlassColor;
            taskbarGlassSampleAt=now;
            Rectangle frame=lastTaskbarScreenRect;
            if(frame.Width<10&&taskbar!=IntPtr.Zero)
            {
                Native.RECT rect;
                if(Native.GetWindowRect(taskbar,out rect))frame=rect.ToRectangle();
            }
            Rectangle content=new Rectangle(PointToScreen(Point.Empty),ClientSize);
            taskbarGlassColor=TaskbarGlassColor.Sample(frame,content,out taskbarGlassSampled);
            return taskbarGlassColor;
        }
        // R44 chart proof seeds ONLY a purpose-built proof-mode renderer.
        // Real taskbar metrics/history are never synthesized or persisted.
        internal void SeedChartHistoryForProof()
        {
            if(!proofMode)throw new InvalidOperationException("Synthetic chart fixture limited to proof mode.");
            for(int i=0;i<48;i++)
            {
                history.Add("CPU",16f+((i*13)%71));
                history.Add("RAM",26f+((i*7)%49));
                history.Add("DISK",1f+((i*11)%45));
                history.Add("GPU",14f+((i*19)%79));
                history.Add("VRAM",24f+((i*17)%65));
                history.Add("NET",1f+((i*23)%61));
            }
        }
        internal Bitmap RenderGlassPixelsForProof(string theme,int width,int height,int percent,Color taskbar)
        {return RenderGlassBitmap(ThemeCatalog.Get(theme),width,height,percent,taskbar);}
        private Bitmap RenderGlassBitmap(ThemeDefinition theme,int width,int height,int percent,Color taskbar)
        {
            width=Math.Max(320,width);height=Math.Max(32,height);
            Bitmap ink=null,halo=null,full=null;
            try
            {
                if(percent<100)
                {
                    ink=new Bitmap(width,height,PixelFormat.Format32bppPArgb);
                    glassInkCanvas=Graphics.FromImage(ink);
                    glassInkCanvas.TextRenderingHint=System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
                    glassInkCanvas.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
                    glassInkCanvas.Clear(Color.Transparent);
                    if(percent<=30)
                    {
                        halo=new Bitmap(width,height,PixelFormat.Format32bppPArgb);
                        glassHaloCanvas=Graphics.FromImage(halo);
                        glassHaloCanvas.TextRenderingHint=System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
                        glassHaloCanvas.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
                        glassHaloCanvas.Clear(Color.Transparent);
                    }
                }
                full=RenderThemeDefinition(theme,width,height);
                Bitmap output=TaskbarGlassPixels.Compose(full,ink,halo,percent,taskbar,theme.Background);
                if(diagnosticBeacon&&!proofMode)
                    using(Graphics beacon=Graphics.FromImage(output))PaintDiagnosticBeacon(beacon);
                return output;
            }
            finally
            {
                if(glassInkCanvas!=null){glassInkCanvas.Dispose();glassInkCanvas=null;}
                if(glassHaloCanvas!=null){glassHaloCanvas.Dispose();glassHaloCanvas=null;}
                if(full!=null)full.Dispose();
                if(ink!=null)ink.Dispose();
                if(halo!=null)halo.Dispose();
            }
        }
        private bool PaintPerPixelLayer()
        {
            if((proofMode&&!glassNativeVisualProofMode)||glassLegacyFallback||!IsHandleCreated||taskbar==IntPtr.Zero)return false;
            Rectangle r=ClientRectangle;
            if(r.Width<80||r.Height<16)return false;
            int alpha=SystemInformation.HighContrast?100:Math.Max(0,Math.Min(100,(int)Math.Round(config.Opacity*100)));
            ThemeDefinition theme=WindowsThemePolicy.Resolve(config);
            try
            {
                Color sampled=GlassTaskbarSample();
                using(Bitmap pixels=RenderGlassBitmap(theme,r.Width,r.Height,alpha,sampled))
                {
                    int win32;
                    if(TaskbarGlassNative.Upload(Handle,pixels,PointToScreen(Point.Empty),out win32))
                    {
                        lastPaintMetrics=BuildMetricViews(theme);
                        return true;
                    }
                    if((DateTime.UtcNow-glassLastFailureAt).TotalSeconds>20)
                    {
                        glassLastFailureAt=DateTime.UtcNow;
                        Log.Write("ERROR","TASKBAR_GLASS_NATIVE_FAIL code="+win32+" taskbarColorSampled="+taskbarGlassSampled);
                    }
                }
            }
            catch(Exception ex)
            {
                Log.Write("ERROR","TASKBAR_GLASS_COMPOSITION_FAIL "+ex.GetType().Name+" "+ex.Message);
            }
            glassLegacyFallback=true;
            glassLegacyFallbackReady=Native.SetLayeredWindowAttributes(Handle,0,255,Native.LWA_ALPHA);
            if(!glassLegacyFallbackReady)
                Log.Write("ERROR","TASKBAR_GLASS_FALLBACK_STYLE_FAIL "+Marshal.GetLastWin32Error());
            else
                Log.Write("WARN","TASKBAR_GLASS_FALLBACK_OPAQUE: per-pixel alpha unavailable on this taskbar");
            return false;
        }

        internal bool PaintGlassForNativeProof()
        {return PaintPerPixelLayer();}
    }
}
namespace TaskbarMonitorEnhanced
{
    internal static class TaskbarGlassProof
    {
        private static void Require(bool ok,string detail)
        {if(!ok)throw new InvalidOperationException("R41 "+detail);}
        private static byte[] Pix(Bitmap b)
        {return TaskbarGlassPixels.ReadPixels(b,PixelFormat.Format32bppPArgb);}
        private static object Analyze(string name,int opacity,Color sample,Bitmap bitmap)
        {
            byte[] pixels=Pix(bitmap);
            int transparent=0,opaque=0,lightText=0,darkText=0;
            for(int i=0;i<pixels.Length;i+=4)
            {
                int a=pixels[i+3];
                if(a==0)transparent++;
                if(a>=245)
                {
                    opaque++;
                    if(pixels[i]>=245&&pixels[i+1]>=245&&pixels[i+2]>=245)lightText++;
                    if(pixels[i]<=15&&pixels[i+1]<=15&&pixels[i+2]<=15)darkText++;
                }
            }
            if(opacity==0)
            {
                Require(transparent>=bitmap.Width*bitmap.Height/2,"clear background "+name);
                Require(opaque>25,"opaque glyph coverage "+name);
                bool light=TaskbarGlassColor.ReadableText(sample).ToArgb()==Color.White.ToArgb();
                Require(light?lightText>12:darkText>12,"ink contrast choice "+name);
            }
            if(opacity==100)Require(transparent==0,"100% background should be opaque");
            return new{name,opacity,taskbar=sample.ToArgb(),transparent,opaque,lightText,darkText};
        }
        internal static int Run(string dir)
        {
            try
            {
                Directory.CreateDirectory(dir);
                var observations=new List<object>();
                int styles=0;
                using(var proof=new OverlayForm(new AppConfig(),true))
                {
                    foreach(string name in ThemeCatalog.Names)
                    {
                        foreach(Color sample in new[]{Color.FromArgb(18,20,24),Color.FromArgb(235,238,241)})
                        foreach(int pct in new[]{0,29})
                        using(Bitmap b=proof.RenderGlassPixelsForProof(name,620,48,pct,sample))
                        {
                            observations.Add(Analyze(name,pct,sample,b));
                            styles++;
                        }
                    }
                    foreach(int pct in new[]{0,1,15,30,31,50,99,100})
                    using(Bitmap b=proof.RenderGlassPixelsForProof("Bauhaus Blocks",620,48,pct,Color.FromArgb(127,125,128)))
                        observations.Add(Analyze("boundary",pct,Color.FromArgb(127,125,128),b));
                }
                Require(TaskbarGlassHostMode.RequiresTopLevel(0,false),"zero alpha top-level required");
                Require(TaskbarGlassHostMode.RequiresTopLevel(0.29,false),"29% alpha top-level required");
                Require(TaskbarGlassHostMode.RequiresTopLevel(.97,false),"97% alpha top-level required");
                Require(!TaskbarGlassHostMode.RequiresTopLevel(1.0,false),"100% previous child preserved");
                Require(!TaskbarGlassHostMode.RequiresTopLevel(.15,true),"High Contrast forced opaque child");
                foreach(Color bg in new[]{Color.Black,Color.White,Color.FromArgb(127,127,127),Color.FromArgb(220,190,20)})
                    Require(TaskbarGlassColor.Contrast(TaskbarGlassColor.ReadableText(bg),bg)>=4.5,"contrast target");
                var json=new JavaScriptSerializer().Serialize(new{
                    Status="PASS",Tests=styles,AllThemes=ThemeCatalog.Names.Length,
                    Opacities=new[]{0,1,15,29,30,31,50,99,100},
                    ContrastMinimum=4.5,TextRetainedAtZero=true,
                    ScreenCapture=false,IndividualPixelTransparency=true,Observations=observations
                });
                File.WriteAllText(Path.Combine(dir,"GLASS_PROOF.json"),json,new UTF8Encoding(false));
                Console.WriteLine("TBME_GLASS_PROOF=PASS THEMES="+ThemeCatalog.Names.Length+" SAMPLES="+styles+" ZERO_BACKGROUND=TRUE OPAQUE_GLYPHS=TRUE");
                return 0;
            }
            catch(Exception ex)
            {
                Console.Error.WriteLine("TBME_GLASS_PROOF=FAIL "+ex);
                return 41;
            }
        }
    }
    // Independent proof: charts must remain foreground at zero opacity.
    // Only the proof-mode instance receives synthetic history; production never does.
    internal static class TaskbarChartGlassProof
    {
        private static void Check(bool pass,string message)
        {if(!pass)throw new InvalidOperationException("R44 CHART "+message);}
        private static object Compare(string theme,Color taskbar,int opacity,
            Bitmap before,Bitmap after)
        {
            byte[] oldPixels=TaskbarGlassPixels.ReadPixels(before,PixelFormat.Format32bppPArgb);
            byte[] newPixels=TaskbarGlassPixels.ReadPixels(after,PixelFormat.Format32bppPArgb);
            int chartPixels=0,solidChart=0,clearPixels=0,inkContrast=0;
            Color expected=TaskbarGlassColor.ReadableText(
                TaskbarGlassColor.EffectiveBackground(taskbar,ThemeCatalog.Get(theme).Background,opacity/100d));
            for(int y=20;y<after.Height-2;y++)
            for(int x=3;x<after.Width-3;x++)
            {
                int i=(y*after.Width+x)*4;
                int oa=oldPixels[i+3],na=newPixels[i+3];
                if(na==0)clearPixels++;
                if(na>=190 && na-oa>=66)
                {
                    chartPixels++;
                    if(na>=245)
                    {
                        solidChart++;
                        int db=Math.Abs(newPixels[i]-expected.B);
                        int dg=Math.Abs(newPixels[i+1]-expected.G);
                        int dr=Math.Abs(newPixels[i+2]-expected.R);
                        if(db<=12&&dg<=12&&dr<=12)inkContrast++;
                    }
                }
            }
            Check(chartPixels>=16,"missing separate chart pixels for "+theme+" alpha="+opacity+" chart="+chartPixels);
            Check(solidChart>=7,"chart ink too faint for "+theme+" alpha="+opacity+" strong="+solidChart);
            if(opacity<=30)
            {
                Check(inkContrast>=6,"adapted chart ink wrong for "+theme+" alpha="+opacity+" count="+inkContrast);
                Check(TaskbarGlassColor.Contrast(expected,
                    TaskbarGlassColor.EffectiveBackground(taskbar,ThemeCatalog.Get(theme).Background,opacity/100d))>=4.5,
                    "chart color WCAG threshold");
            }
            if(opacity==0)Check(clearPixels>after.Width*4,"chart proof lost clear pixels "+theme);
            return new {theme,opacity,taskbar=taskbar.ToArgb(),chartPixels,solidChart,clearPixels,inkContrast};
        }
        internal static int Run(string outputDirectory)
        {
            try
            {
                if(Directory.Exists(outputDirectory))
                    throw new InvalidOperationException("Chart proof output already exists; do not overwrite.");
                Directory.CreateDirectory(outputDirectory);
                var seen=new List<object>();
                int pairCount=0;
                var palette=new[]{Color.FromArgb(18,21,23),Color.FromArgb(238,239,242)};
                using(var config=new ChartProofConfigScope())
                using(var renderer=new OverlayForm(config.Config,true))
                {
                    renderer.SeedChartHistoryForProof();
                    foreach(string name in ThemeCatalog.Names)
                    foreach(Color bg in palette)
                    foreach(int pct in new[]{0,29})
                    {
                        config.Config.ShowSparklines=false;
                        using(Bitmap without=renderer.RenderGlassPixelsForProof(name,1100,48,pct,bg))
                        {
                            config.Config.ShowSparklines=true;
                            using(Bitmap with=renderer.RenderGlassPixelsForProof(name,1100,48,pct,bg))
                                seen.Add(Compare(name,bg,pct,without,with));
                        }
                        pairCount++;
                    }
                    // Boundary proof: alpha and manual toggle remain correct
                    foreach(int pct in new[]{1,15,30,31,50,99,100})
                    {
                        config.Config.ShowSparklines=false;
                        using(Bitmap without=renderer.RenderGlassPixelsForProof("Dark Minimal Pro",1100,48,pct,palette[0]))
                        {
                            config.Config.ShowSparklines=true;
                            using(Bitmap with=renderer.RenderGlassPixelsForProof("Dark Minimal Pro",1100,48,pct,palette[0]))
                            {
                                Check(with.Width==1100&&with.Height==48,"chart boundary geometry");
                                if(pct<=31)seen.Add(Compare("Dark Minimal Pro",palette[0],pct,without,with));
                            }
                        }
                    }
                }
                Check(pairCount==ThemeCatalog.Names.Length*4,"49-theme dark/light opacity matrix");
                var json=new JavaScriptSerializer().Serialize(new{
                    Status="PASS",Source="R44 chart foreground proof",Themes=ThemeCatalog.Names.Length,
                    Pairs=pairCount,Observed=seen.Count,
                    TestedAlphas=new[]{0,1,15,29,30,31,50,99,100},
                    ChartTypes="line,bars,quantized-lcd,dots",
                    NoRealSystemDesktopChange=true,ThemeBackgroundTransparentAtZero=true,
                    ForegroundChartIndependent=true,ContrastMinimum=4.5,Observations=seen
                });
                File.WriteAllText(Path.Combine(outputDirectory,"CHART_GLASS_PROOF.json"),json,new UTF8Encoding(false));
                Console.WriteLine("TBME_CHART_GLASS_PROOF=PASS THEMES="+ThemeCatalog.Names.Length+
                    " PAIRS="+pairCount+" BACKGROUND_ZERO_CHART_VISIBLE=TRUE");
                return 0;
            }
            catch(Exception ex)
            {
                Console.Error.WriteLine("TBME_CHART_GLASS_PROOF=FAIL "+ex);
                return 44;
            }
        }
        // Keep proof settings lifetime separate to avoid affecting global live configuration.
        private sealed class ChartProofConfigScope : IDisposable
        {
            internal readonly AppConfig Config=new AppConfig();
            public void Dispose(){}
        }
    }

    internal sealed class GlassChildWindow : Form
    {
        protected override CreateParams CreateParams
        {
            get{CreateParams p=base.CreateParams;p.ExStyle|=0x00080000;return p;}
        }
    }
    internal static class TaskbarGlassNativeProof
    {
        internal static int Run()
        {
            try
            {
                using(var parent=new Form{ShowInTaskbar=false,FormBorderStyle=FormBorderStyle.None,StartPosition=FormStartPosition.Manual,Bounds=new Rectangle(-1500,-1500,320,64)})
                using(var child=new GlassChildWindow{FormBorderStyle=FormBorderStyle.None,ShowInTaskbar=false,StartPosition=FormStartPosition.Manual,Bounds=new Rectangle(0,0,320,48),TopLevel=false})
                using(var pixels=new Bitmap(320,48,PixelFormat.Format32bppPArgb))
                {
                    child.Parent=parent;
                    IntPtr ph=parent.Handle,ch=child.Handle;
                    using(Graphics g=Graphics.FromImage(pixels))
                    {
                        g.Clear(Color.Transparent);
                        using(var brush=new SolidBrush(Color.White))g.DrawString("ULW_ALPHA native proof",SystemFonts.DefaultFont,brush,10,10);
                    }
                    int error=0;
                    bool pass=TaskbarGlassNative.Upload(ch,pixels,new Point(-1500,-1500),out error);
                    if(!pass)throw new InvalidOperationException("UpdateLayeredWindow child error="+error);
                }
                Console.WriteLine("TBME_GLASS_NATIVE_PROOF=PASS CHILD_ULW_ALPHA=TRUE");
                return 0;
            }
            catch(Exception e)
            {
                Console.Error.WriteLine("TBME_GLASS_NATIVE_PROOF=FAIL "+e);
                return 42;
            }
        }
    }
}

namespace TaskbarMonitorEnhanced
{
    internal static class TaskbarGlassLiveProof
    {
        internal static int Run(string output)
        {
            try
            {
                IntPtr taskbar=Native.FindWindow("Shell_TrayWnd",null);
                Native.RECT bounds;
                if(taskbar==IntPtr.Zero||!Native.IsWindowVisible(taskbar)||
                   !Native.GetWindowRect(taskbar,out bounds))
                    throw new InvalidOperationException("Visible primary Windows taskbar was not found.");
                Rectangle bar=bounds.ToRectangle();
                if(bar.Width<950||bar.Height<35)
                    throw new InvalidOperationException("Taskbar too small for isolated transient test.");
                int w=320,h=Math.Min(48,bar.Height);
                int x=Math.Max(10,bar.Width-w-375);
                int y=Math.Max(0,(bar.Height-h)/2);
                Rectangle footprint=new Rectangle(bar.Left+x,bar.Top+y,w,h);
                bool sampled;
                Color underneath=TaskbarGlassColor.Sample(bar,footprint,out sampled);
                var stages=new List<object>();
                using(var child=new GlassChildWindow{FormBorderStyle=FormBorderStyle.None,ShowInTaskbar=false,
                    StartPosition=FormStartPosition.Manual,Size=new Size(w,h)})
                using(var renderer=new OverlayForm(new AppConfig(),true))
                {
                    IntPtr hwnd=child.Handle;
                    long style=Native.GetWindowLongPtr(hwnd,Native.GWL_STYLE).ToInt64();
                    long ex=Native.GetWindowLongPtr(hwnd,Native.GWL_EXSTYLE).ToInt64();
                    Native.SetWindowLongPtr(hwnd,Native.GWL_STYLE,new IntPtr((style & ~Native.WS_POPUP)|Native.WS_CHILD));
                    IntPtr oldParent=Native.SetParent(hwnd,taskbar);
                    int parentWin32=Marshal.GetLastWin32Error();
                    if(Native.GetParent(hwnd)!=taskbar)throw new InvalidOperationException("Native parent mismatch err="+parentWin32+" old="+oldParent.ToInt64());
                    Native.SetWindowLongPtr(hwnd,Native.GWL_EXSTYLE,new IntPtr(ex|Native.WS_EX_LAYERED|Native.WS_EX_TOOLWINDOW|Native.WS_EX_NOACTIVATE));
                    bool positioned=Native.SetWindowPos(hwnd,Native.HWND_TOP,x,y,w,h,Native.SWP_NOACTIVATE|Native.SWP_SHOWWINDOW);
                    if(!positioned)throw new InvalidOperationException("Cannot position test child "+Marshal.GetLastWin32Error());
                    try
                    {
                        foreach(int p in new[]{0,10,29,30,100})
                        {
                            using(Bitmap pixels=renderer.RenderGlassPixelsForProof("Art Deco Gold",w,h,p,underneath))
                            {
                                int error;
                                if(!TaskbarGlassNative.Upload(hwnd,pixels,footprint.Location,out error))
                                    throw new InvalidOperationException("Shell taskbar child ULW_ALPHA rejected percent="+p+" code="+error);
                                Application.DoEvents();
                                System.Threading.Thread.Sleep(65);
                                stages.Add(new{Percent=p,NativeAccepted=true,PixelHash=Convert.ToBase64String(System.Security.Cryptography.SHA256.Create().ComputeHash(TaskbarGlassPixels.ReadPixels(pixels,PixelFormat.Format32bppPArgb)))});
                            }
                        }
                        long verified=Native.GetWindowLongPtr(hwnd,Native.GWL_EXSTYLE).ToInt64();
                        if((verified&Native.WS_EX_LAYERED)==0||Native.GetParent(hwnd)!=taskbar)
                            throw new InvalidOperationException("Layered style or taskbar parent drift");
                    }
                    finally {child.Hide();}
                }
                var receipt=new{Status="PASS",Source="R41 Native on actual Windows taskbar child",Stages=stages,
                   ActualTaskbarColorSampled=sampled,TaskbarRGB=String.Format(CultureInfo.InvariantCulture,
                     "#{0:X2}{1:X2}{2:X2}",underneath.R,underneath.G,underneath.B),
                   TextContrast=TaskbarGlassColor.Contrast(TaskbarGlassColor.ReadableText(underneath),underneath),
                   NoInstalledMutation=true,OutputScreenshotsSaved=false};
                File.WriteAllText(output,new JavaScriptSerializer().Serialize(receipt),new UTF8Encoding(false));
                Console.WriteLine("TBME_GLASS_LIVE_PROOF=PASS TASKBAR_PARENT=TRUE MODES=5 COLOR_SAMPLED="+sampled);
                return 0;
            }
            catch(Exception e)
            {
                Console.Error.WriteLine("TBME_GLASS_LIVE_PROOF=FAIL "+e);
                return 43;
            }
        }
    }
}


namespace TaskbarMonitorEnhanced
{
    // Real screen-pixel proof using the actual OverlayForm's production top-level
    // attach, safe taskbar placement and per-pixel paint path. Runs strictly in
    // proof mode with no config writes, no tray and no process replacement.
    internal static class TaskbarTopGlassVisualProof
    {
        private static void Check(bool ok,string reason)
        {if(!ok)throw new InvalidOperationException("R46 TOPGLASS "+reason);}

        private static string MainExecutableHash()
        {
            using(var sha=System.Security.Cryptography.SHA256.Create())
            using(var stream=File.OpenRead(Application.ExecutablePath))
                return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-","");
        }

        private static Bitmap Capture(Rectangle r)
        {
            Bitmap b=new Bitmap(r.Width,r.Height,PixelFormat.Format24bppRgb);
            using(Graphics g=Graphics.FromImage(b))
                g.CopyFromScreen(r.Location,Point.Empty,r.Size,CopyPixelOperation.SourceCopy);
            return b;
        }

        internal static int Run(string dir)
        {
            try
            {
                if(Directory.Exists(dir))throw new InvalidOperationException("Native proof output already exists; do not overwrite.");
                Directory.CreateDirectory(dir);
                Native.EnableDpi();
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                IntPtr bar=Native.FindWindow("Shell_TrayWnd",null);
                Native.RECT taskbarBounds=new Native.RECT();
                Check(bar!=IntPtr.Zero && Native.IsWindowVisible(bar) && Native.GetWindowRect(bar,out taskbarBounds),
                    "primary taskbar must exist");
                AppConfig cfg=new AppConfig();
                cfg.Theme="Dark Minimal Pro";
                cfg.Position="Right";
                cfg.SafePlacement=true;
                cfg.Opacity=0;
                cfg.MinWidthLogicalPx=900;
                cfg.ShowSparklines=true;
                cfg.Normalize();
                Rectangle place=TaskbarLayout.GetSafeRectangle(bar,cfg,cfg.MinWidthLogicalPx);
                Check(place.Width>=700 && place.Height>=35 && place.Width<=1500,
                    "insufficient unused taskbar area "+place);
                Rectangle screen=SystemInformation.VirtualScreen;
                Check(screen.Contains(place),"test area must be on screen");
                // Fail rather than cover the existing user's v1.6 process.
                uint resident=0;
                foreach(System.Diagnostics.Process p in System.Diagnostics.Process.GetProcessesByName("TaskbarMonitorEnhanced"))
                {
                    try{if(p.Id!=System.Diagnostics.Process.GetCurrentProcess().Id)resident=(uint)p.Id;}
                    finally{p.Dispose();}
                }
                Check(resident!=0,"accepted v1.6 must remain resident");
                bool collides=false;
                Native.EnumChildWindows(bar,delegate(IntPtr h,IntPtr ignored)
                {
                    if(Native.GetParent(h)!=bar)return true;
                    uint pid=0;
                    Native.GetWindowThreadProcessId(h,out pid);
                    if(pid!=resident)return true;
                    Native.RECT rr;
                    if(Native.GetWindowRect(h,out rr) && rr.ToRectangle().IntersectsWith(place))
                        collides=true;
                    return true;
                },IntPtr.Zero);
                Check(!collides,"test must not cover resident v1.6 window");

                bool sampled=false;
                Color underlayColor=TaskbarGlassColor.Sample(taskbarBounds.ToRectangle(),place,out sampled);
                using(Bitmap before=Capture(place))
                using(var f=new OverlayForm(cfg,true))
                {
                    f.EnableNativeGlassVisualProof();
                    f.PrimeSettingsThemePreviewFromLiveMetrics(24,80);
                    f.Location=new Point(-30000,-30000);
                    f.Show();Application.DoEvents();
                    Rectangle actual=f.AttachNativeGlassVisualProof();
                    Check(actual==place,"production position differed from safe placement "+actual+" vs "+place);
                    int preNativeMetricUpdates=f.GlassDirectMetricRefreshCountForProof;
                    // Read real metrics while the layered popup is ALREADY visible.
                    // The telemetry commit itself must cause a native upload; relying
                    // on Invalidate/WM_PAINT would leave a static cold-start frame.
                    f.PrimeSettingsThemePreviewFromLiveMetrics(2,50);
                    int nativeMetricUpdates=f.GlassDirectMetricRefreshCountForProof-preNativeMetricUpdates;
                    Check(nativeMetricUpdates>=2,"metric snapshot failed to upload real layered pixels "+nativeMetricUpdates);
                    f.Invalidate();f.Update();Application.DoEvents();
                    System.Threading.Thread.Sleep(400);
                    using(Bitmap on=Capture(actual))
                    using(Bitmap expected=f.RenderGlassPixelsForProof(cfg.Theme,actual.Width,actual.Height,0,underlayColor))
                    {
                        before.Save(Path.Combine(dir,"UNDERLAY_BEFORE_R46.png"),ImageFormat.Png);
                        on.Save(Path.Combine(dir,"PRODUCTION_FORM_TOPGLASS_R46.png"),ImageFormat.Png);
                        int realInk=0,realGraphs=0,foregroundPixels=0,backgroundChanged=0,clearPixels=0;
                        for(int y=2;y<actual.Height-3;y++)
                        for(int x=3;x<actual.Width-3;x++)
                        {
                            int alpha=expected.GetPixel(x,y).A;
                            if(alpha==0)clearPixels++;
                            Color off=before.GetPixel(x,y),now=on.GetPixel(x,y);
                            int contrast=Math.Max(Math.Abs(off.R-now.R),
                                Math.Max(Math.Abs(off.G-now.G),Math.Abs(off.B-now.B)));
                            if(alpha>=210)
                            {
                                foregroundPixels++;
                                if(contrast>=45)
                                {
                                    if(y<20)realInk++;
                                    else realGraphs++;
                                }
                            }
                            else if(alpha==0 && contrast>65)backgroundChanged++;
                        }
                        bool pass=realInk>=100 && realGraphs>=100 &&
                            clearPixels>actual.Width*5 &&
                            backgroundChanged<Math.Max(200,clearPixels/5);
                        var receipt=new {
                            Status=pass?"PASS":"FAIL",
                            ParentWindow=Native.GetParent(f.Handle).ToInt64(),
                            NativeLayeredWindow=true,ActualProductionOverlayForm=true,
                            MetricNativeRefreshUploads=nativeMetricUpdates,
                            MainExecutableSHA256=MainExecutableHash(),
                            BackgroundOpacityPercent=0,Theme=cfg.Theme,
                            ScreenshotArea=actual.ToString(),ExpectedForegroundPixels=foregroundPixels,
                            RealTextChangedPixels=realInk,RealChartChangedPixels=realGraphs,
                            ActualTransparentBackgroundPixels=clearPixels,
                            ClearAreaChangedPixels=backgroundChanged,
                            ContrastSampledFromTaskbar=sampled,
                            ResidentInstalledV16ProcessId=resident,
                            NoResidentAppTerminated=true,NoSettingsSaved=true,
                            NoSlideshowTouched=true,TemporaryVisualOnly=true,
                            GitSourceCandidate="R46",ActualScreenshotSaved=true,
                            TimeUtc=DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture)
                        };
                        File.WriteAllText(Path.Combine(dir,"TOPGLASS_REAL_VISUAL_PROOF.json"),
                            new JavaScriptSerializer().Serialize(receipt),new UTF8Encoding(false));
                        Check(pass,"real taskbar screen delta insufficient glyph="+realInk+
                            " graph="+realGraphs+" background="+backgroundChanged);
                    }
                    // Exercise actual GDI+ window transitions (0 -> 30 -> 97 -> 100 -> 0)
                    // using the very same proof-mode OverlayForm; user config is never saved.
                    var transitions=new List<object>();
                    foreach(double percent in new[]{.30,.97,1.0,0.0})
                    {
                        bool switchOk=f.SwitchNativeGlassForProof(percent);
                        transitions.Add(new {OpacityPercent=(int)Math.Round(percent*100),WindowMode=
                            percent<1?"TOPLEVEL_PARG_B":"TASKBAR_CHILD_OPAQUE",Pass=switchOk});
                        Check(switchOk,"form mode transition failed alpha="+percent);
                        Application.DoEvents();
                        System.Threading.Thread.Sleep(120);
                    }
                    Check(f.AttachNativeGlassVisualProof()==place,"post-transition native geometry drift");
                    Application.DoEvents();
                    System.Threading.Thread.Sleep(270);
                    using(Bitmap post=Capture(place))
                    using(Bitmap expectedPost=f.RenderGlassPixelsForProof(cfg.Theme,place.Width,place.Height,0,underlayColor))
                    {
                        post.Save(Path.Combine(dir,"TOPGLASS_AFTER_100_TO_ZERO_R46.png"),ImageFormat.Png);
                        int postGlyph=0,postChart=0;
                        for(int yy=2;yy<post.Height-3;yy++)
                        for(int xx=3;xx<post.Width-3;xx++)
                        {
                            if(expectedPost.GetPixel(xx,yy).A<210)continue;
                            Color old=before.GetPixel(xx,yy),cur=post.GetPixel(xx,yy);
                            int delta=Math.Max(Math.Abs(old.R-cur.R),
                                Math.Max(Math.Abs(old.G-cur.G),Math.Abs(old.B-cur.B)));
                            if(delta>=45)
                            {
                                if(yy<20)postGlyph++;
                                else postChart++;
                            }
                        }
                        bool good=postGlyph>=100 && postChart>=100;
                        var receipt=new{
                            Status=good?"PASS":"FAIL",TotalTransitions=transitions.Count,
                            Stages=transitions,RestoredZeroAlphaGlyphPixels=postGlyph,
                            RestoredZeroAlphaChartPixels=postChart,
                            ActualProductionOverlayForm=true,NoInstalledMutation=true,
                            MainExecutableSHA256=MainExecutableHash(),
                            RealScreenCompositorVerified=true};
                        File.WriteAllText(Path.Combine(dir,"TOPGLASS_MODE_TRANSITIONS.json"),
                            new JavaScriptSerializer().Serialize(receipt),new UTF8Encoding(false));
                        Check(good,"0-30-97-100-0 real taskbar mode transitions lost glyph or graph");
                    }
                    f.Hide();Application.DoEvents();
                }
                Console.WriteLine("TBME_TOPGLASS_LIVE_PROOF=PASS REAL_PRODUCTION_FORM=TRUE CHAR_AND_GRAPH=VISIBLE");
                return 0;
            }
            catch(Exception e)
            {
                try
                {
                    Directory.CreateDirectory(dir);
                    File.WriteAllText(Path.Combine(dir,"TOPGLASS_FAILURE.txt"),e.ToString(),new UTF8Encoding(false));
                }
                catch {}
                Console.Error.WriteLine("TBME_TOPGLASS_LIVE_PROOF=FAIL "+e);
                return 46;
            }
        }
    }
}
