using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace TaskbarMonitorEnhanced
{
    internal sealed partial class OverlayForm
    {
        private WorkspaceForm workspace;
        private bool lastBalloonWasUsage;
        private string FormatTaskbarNetworkRate(double bytes){return config.NetworkRateInBits?NetworkRateFormatter.Bits(bytes):UnitFormatter.Rate(bytes,config.NetworkUnit);}
        internal string WorkspaceNetworkTextForProof(){return String.Join(" ",BuildMetricViews(ThemeCatalog.Get(config.Theme),1100).Where(m=>m.GroupKey=="NET").Select(m=>m.Value+" "+m.Value2).ToArray());}
        internal int VerifyStudioGeometry()
        {
            if(!proofMode)throw new InvalidOperationException("Proof instance required.");
            var fingerprints=new HashSet<string>(StringComparer.Ordinal);
            ThemeDefinition p=ThemeCatalog.Get("Art Deco Gold");
            foreach(var design in StudioThemes.Create())
            {
                var samePalette=new ThemeDefinition("Geometry",p.Background,p.Background2,p.Foreground,p.Muted,p.Border,p.Accents,design.Mode,"Segoe UI",false);
                using(var bitmap=RenderThemeDefinition(samePalette,1100,48))using(var bytes=new MemoryStream())
                using(var hash=System.Security.Cryptography.SHA256.Create())
                {bitmap.Save(bytes,ImageFormat.Png);fingerprints.Add(Convert.ToBase64String(hash.ComputeHash(bytes.ToArray())));}
            }
            if(fingerprints.Count!=20)throw new InvalidOperationException("Studio geometries are not all distinct at identical colors/font/metrics.");
            return fingerprints.Count;
        }
        internal MetricsSnapshot WorkspaceSnapshotForProof(){return snapshot;}
        internal void WorkspaceReadForProof(){if(!proofMode)throw new InvalidOperationException("Proof instance required.");ReadMetrics();}
        internal string[] WorkspaceMetricKeysForProof(){return BuildMetricViews(ThemeCatalog.Get(config.Theme),1100).Select(m=>m.Key).ToArray();}
        private readonly TrafficLedger trafficLedger=new TrafficLedger(Path.Combine(AppPaths.Root,"traffic_history.json"));
        private readonly SustainedAlertGate usageGate=new SustainedAlertGate();
        private readonly Queue<AlertRecord> alertRecords=new Queue<AlertRecord>();
        private DateTime notificationsSnoozedUntil=DateTime.MinValue;
        private readonly Stopwatch workspaceClock=Stopwatch.StartNew();
        private double lastWorkspaceSample=-1;
        private bool NotificationsMuted()
        {return DateTime.UtcNow<notificationsSnoozedUntil||SustainedAlertGate.IsQuiet(config.QuietHoursEnabled,config.QuietHoursStart,config.QuietHoursEnd,DateTime.Now);}
        private void CommitWorkspaceSample()
        {
            if(proofMode||telemetryPaused)return;
            double at=workspaceClock.Elapsed.TotalSeconds;
            if(lastWorkspaceSample>=0&&at-lastWorkspaceSample>30)usageGate.Reset();
            lastWorkspaceSample=at;
            trafficLedger.Observe(snapshot,config,DateTime.Now,at);
            if(!config.EnableUsageNotifications||NotificationsMuted()||telemetryPaused){usageGate.Reset();return;}
            var messages=new List<string>();
            Action<string,bool,double,int> test=(id,available,value,threshold)=>{
                if(usageGate.Observe(id,available,value,threshold,at,config.SustainedAlertSeconds,config.UsageAlertCooldownMinutes)){
                    string text=id+" reached "+value.ToString("0.0",CultureInfo.InvariantCulture)+"% for at least "+config.SustainedAlertSeconds+" seconds.";
                    RecordAlert(id,text);messages.Add(text);
                }
            };
            test("CPU usage",true,snapshot.Cpu,config.CpuUsageWarningPercent);
            test("RAM usage",snapshot.RamTotalBytes>0,snapshot.Ram,config.RamUsageWarningPercent);
            test("GPU usage",snapshot.GpuDevices.Any(d=>d.UsageAvailable),snapshot.Gpu,config.GpuUsageWarningPercent);
            var capacities=snapshot.DiskDevices.Where(d=>d.CapacityAvailable&&d.TotalBytes>0).ToList();
            test("Disk capacity",capacities.Count>0,capacities.Count>0?capacities.Max(d=>d.UsedPercent):0,config.DiskSpaceWarningPercent);
            if(messages.Count>0&&trayIcon!=null)try{lastBalloonWasUsage=true;trayIcon.ShowBalloonTip(10000,"Taskbar Monitor - sustained load",String.Join("\n",messages.ToArray()),ToolTipIcon.Warning);}catch(Exception ex){Log.Write("WARN","USAGE_NOTIFICATION "+ex.GetType().Name);}
        }
        private void RecordAlert(string metric,string message)
        {alertRecords.Enqueue(new AlertRecord{Utc=DateTime.UtcNow,Metric=metric,Message=message});while(alertRecords.Count>200)alertRecords.Dequeue();}
        private void ApplyWorkspaceConfig()
        {
            config.Normalize();history.SetLimit(config.SparklineHistoryLength);Opacity=config.Opacity;
            if(!proofMode){config.Save();TaskbarLayout.ResetCache();ResetPlacementStability("WORKSPACE_APPLY");PositionOverlay(true);RefreshTelemetryTimerInterval();RefreshMenuChecks();}
            Invalidate();
        }
        private void OpenWorkspace(string page)
        {
            if(workspace!=null&&!workspace.IsDisposed){workspace.SelectPage(page);workspace.Show();workspace.BringToFront();workspace.Activate();return;}
            if(hardwareFlyout!=null)hardwareFlyout.Hide();
            workspace=new WorkspaceForm(config,()=>snapshot,()=>telemetryPaused,b=>SetUserTelemetryPaused(b),trafficLedger,
                ()=>alertRecords.Reverse().ToArray(),()=>{notificationsSnoozedUntil=DateTime.UtcNow.AddMinutes(30);},ApplyWorkspaceConfig,RenderSettingsThemePreview);
            workspace.FormClosed+=delegate{workspace=null;};workspace.SelectPage(page);workspace.Show();
        }
        private void AddWorkspaceMenu(ContextMenuStrip m)
        {
            var dashboard=new ToolStripMenuItem("Performance workspace...");dashboard.Click+=delegate{OpenWorkspace("Overview");};m.Items.Add(dashboard);
            var studio=new ToolStripMenuItem("Theme Studio - 48 designs...");studio.Click+=delegate{OpenWorkspace("Themes");};m.Items.Add(studio);
            var snooze=new ToolStripMenuItem("Snooze all notifications for 30 minutes");snooze.Click+=delegate{notificationsSnoozedUntil=DateTime.UtcNow.AddMinutes(30);};m.Items.Add(snooze);
        }
        private void CloseWorkspace()
        {
            if(workspace!=null){workspace.Close();workspace=null;}
            if(!proofMode&&config.RecordTrafficHistory&&!trafficLedger.FlushAndWait(1500))Log.Write("WARN","TRAFFIC_HISTORY_SHUTDOWN_INCOMPLETE");
        }
        private List<MetricView> OrderWorkspaceMetrics(List<MetricView> views)
        {
            var order=(config.MetricOrder??"CPU;RAM;DISK;GPU;VRAM;NET").Split(';');
            return views.OrderBy(v=>{int i=Array.IndexOf(order,v.Key=="VRAM"?"VRAM":v.GroupKey??v.Key);return i<0?order.Length:i;}).ToList();
        }
    }

    internal sealed class WorkspaceTabs : TabControl
    {
        internal ThemeDefinition Palette=ThemeCatalog.Get("Dark Minimal Pro");
        internal WorkspaceTabs()
        {
            DrawMode=TabDrawMode.OwnerDrawFixed;Padding=new Point(14,7);
            AccessibleName="Performance workspace pages";AccessibleDescription="Use Control plus 1 through 8 to select a page.";
        }
        protected override void OnDrawItem(DrawItemEventArgs e)
        {
            if(e.Index<0||e.Index>=TabPages.Count)return;
            var p=Palette;bool selected=e.Index==SelectedIndex;Rectangle r=GetTabRect(e.Index);
            using(var bg=new SolidBrush(selected?p.Background2:p.Background))e.Graphics.FillRectangle(bg,r);
            TextRenderer.DrawText(e.Graphics,TabPages[e.Index].Text,Font,r,p.Foreground,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);
            if(selected)using(var pen=new Pen(p.Accents[0],3))e.Graphics.DrawLine(pen,r.Left+4,r.Bottom-2,r.Right-4,r.Bottom-2);
            if(Focused&&selected)ControlPaint.DrawFocusRectangle(e.Graphics,Rectangle.Inflate(r,-4,-4),p.Foreground,p.Background2);
        }
    }

    internal sealed class HistoryChart : Control
    {
        internal SessionTelemetrySample[] Samples=new SessionTelemetrySample[0];
        internal int Metric; internal ThemeDefinition Theme=ThemeCatalog.Get("Dark Minimal Pro");
        private int hover=-1;
        internal HistoryChart(){DoubleBuffered=true;SetStyle(ControlStyles.ResizeRedraw,true);AccessibleName="Session history chart";AccessibleDescription="Time-based live history. Move the pointer to inspect an observed sample. Missing data and gaps are not interpolated.";MouseMove+=(s,e)=>{hover=e.X;Invalidate();};MouseLeave+=(s,e)=>{hover=-1;Invalidate();};}
        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);var g=e.Graphics;g.SmoothingMode=SmoothingMode.AntiAlias;g.Clear(Theme.Background2);
            RectangleF plot=new RectangleF(60,32,Math.Max(10,Width-84),Math.Max(10,Height-74));
            using(var pen=new Pen(Theme.Border,1))using(var fg=new SolidBrush(Theme.Muted)){
                for(int i=0;i<=4;i++){float yy=plot.Y+plot.Height*i/4;g.DrawLine(pen,plot.X,yy,plot.Right,yy);}
                if(Samples.Length<2){g.DrawString("Collecting live samples...",Font,fg,plot.X+15,plot.Y+30);return;}
                double[] values=Samples.Select(s=>WorkspaceMetric.Value(s,Metric)).Where(v=>v.HasValue&&MetricStatistics.Finite(v.Value)).Select(v=>v.Value).ToArray();
                double maximum=Metric<4?100:Math.Max(1,values.Length>0?values.Max()*1.12:1);
                DateTime from=Samples.First().Utc,to=Samples.Last().Utc;double seconds=Math.Max(.001,(to-from).TotalSeconds);
                for(int i=0;i<=4;i++)g.DrawString((maximum*(4-i)/4).ToString("0.#",CultureInfo.InvariantCulture),Font,fg,5,plot.Y+plot.Height*i/4-7);
                g.DrawString(from.ToLocalTime().ToString("HH:mm:ss"),Font,fg,plot.X,plot.Bottom+12);
                g.DrawString(to.ToLocalTime().ToString("HH:mm:ss"),Font,fg,Math.Max(plot.X,plot.Right-70),plot.Bottom+12);
                using(var line=new Pen(Theme.Accents[Metric%Theme.Accents.Length],2)){
                    PointF? last=null;DateTime lastAt=DateTime.MinValue;
                    foreach(var s in Samples){double? value=WorkspaceMetric.Value(s,Metric);if(!value.HasValue||!MetricStatistics.Finite(value.Value)){last=null;continue;}
                        PointF p=new PointF(plot.X+(float)((s.Utc-from).TotalSeconds/seconds)*plot.Width,plot.Bottom-(float)(Math.Max(0,Math.Min(maximum,value.Value))/maximum)*plot.Height);
                        if(last.HasValue&&(s.Utc-lastAt).TotalSeconds<=30&&(s.Utc-lastAt).TotalSeconds>=0)g.DrawLine(line,last.Value,p);last=p;lastAt=s.Utc;
                    }
                }
                if(hover>=plot.X&&hover<=plot.Right){DateTime at=from.AddSeconds((hover-plot.X)/plot.Width*seconds);var nearest=Samples.OrderBy(s=>Math.Abs((s.Utc-at).Ticks)).First();var value=WorkspaceMetric.Value(nearest,Metric);
                    using(var cursor=new Pen(Theme.Muted,1)){cursor.DashStyle=DashStyle.Dash;g.DrawLine(cursor,hover,plot.Y,hover,plot.Bottom);}
                    string text=nearest.Utc.ToLocalTime().ToString("HH:mm:ss")+"   "+(value.HasValue?value.Value.ToString("0.###",CultureInfo.InvariantCulture):"Unavailable");g.DrawString(text,Font,fg,plot.X,8);
                }
            }
        }
    }

    internal sealed class WorkspaceForm : Form
    {
        private readonly AppConfig config;
        private readonly Func<MetricsSnapshot> live;private readonly Func<bool> paused;private readonly Action<bool> setPaused;
        private readonly TrafficLedger traffic;private readonly Func<AlertRecord[]> alerts;private readonly Action snooze,apply;
        private readonly Func<string,int,int,Bitmap> render;
        private readonly System.Windows.Forms.Timer timer=new System.Windows.Forms.Timer();
        private readonly WorkspaceTabs tabs=new WorkspaceTabs{Dock=DockStyle.Fill};
        private readonly Label status=new Label{Dock=DockStyle.Bottom,Height=32,Padding=new Padding(10,7,0,0)};
        private HistoryChart chart;private ComboBox metric,window,processSort,themeFilter,adapterChoice;
        private Label stats,trafficSummary,themeInfo,hardwareSummary;
        private TextBox processSearch,themeSearch,hardwareSearch;
        private CheckBox freezeChart,freezeProcesses,persistTraffic,bits,usageEnabled,quietEnabled;
        private NumericUpDown budget,cpuWarn,ramWarn,gpuWarn,diskWarn,dwell,cooldown,quietStart,quietEnd;
        private DataGridView processes,network,trafficDays,storage,events,hardware;
        private List<HardwareRow> hardwareRows=new List<HardwareRow>();
        private ListBox themes,order;
        private ThemePreviewControl preview;
        private readonly ProcessSampler processSampler=new ProcessSampler();private int processBusy;
        private List<ProcessRow> processRows=new List<ProcessRow>();
        private readonly List<string> adapterIds=new List<string>();
        private string lastAdapterSignature=null;
        private bool proof;
        internal WorkspaceForm(AppConfig c,Func<MetricsSnapshot> snapshot,Func<bool> isPaused,Action<bool> pause,TrafficLedger ledger,Func<AlertRecord[]> records,Action snoozeAction,Action applyAction,Func<string,int,int,Bitmap> renderer,bool proofMode=false)
        {
            config=c;live=snapshot;paused=isPaused;setPaused=pause;traffic=ledger;alerts=records;snooze=snoozeAction;apply=applyAction;render=renderer;proof=proofMode;
            Text="Taskbar Monitor Enhanced - Performance Workspace";Font=new Font("Segoe UI",9f);AutoScaleMode=AutoScaleMode.Dpi;
            StartPosition=FormStartPosition.CenterScreen;ClientSize=new Size(1120,740);MinimumSize=new Size(900,620);KeyPreview=true;
            try{Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath);}catch{}
            var title=new Label{Text="PERFORMANCE WORKSPACE  /  "+BuildInfo.PublicVersion,Dock=DockStyle.Top,Height=54,Padding=new Padding(18,14,0,0),Font=new Font("Segoe UI Semibold",15f)};
            Controls.Add(tabs);Controls.Add(status);Controls.Add(title);
            BuildOverview();BuildProcesses();BuildNetwork();BuildStorage();BuildAlerts();BuildThemes();BuildProfiles();BuildHardware();
            ApplyPalette();tabs.SelectedIndexChanged+=delegate{RefreshPage();};
            timer.Interval=2000;timer.Tick+=delegate{try{RefreshPage();}catch(Exception ex){status.Text="Refresh unavailable: "+ex.GetType().Name;}};
            Shown+=delegate{RefreshPage();if(!proof)timer.Start();};FormClosed+=delegate{timer.Stop();timer.Dispose();};
            KeyDown+=(s,e)=>{if(e.KeyCode==Keys.Escape){Close();e.Handled=true;}else if(e.KeyCode==Keys.F5){RefreshPage();e.Handled=true;}else if(e.Control&&e.KeyCode>=Keys.D1&&e.KeyCode<=Keys.D8){tabs.SelectedIndex=(int)e.KeyCode-(int)Keys.D1;e.Handled=true;}};
        }
        internal void SelectPage(string name){foreach(TabPage p in tabs.TabPages)if(p.Text==name){tabs.SelectedTab=p;break;}}
        private TabPage Page(string name){var p=new TabPage(name){Padding=new Padding(12),AutoScroll=true};tabs.TabPages.Add(p);return p;}
        private FlowLayoutPanel Bar(){return new FlowLayoutPanel{Dock=DockStyle.Top,AutoSize=true,WrapContents=true,Padding=new Padding(0,2,0,8)};}
        private Button Button(string text,Action action){var b=new Button{Text=text,AutoSize=true,MinimumSize=new Size(96,32),Margin=new Padding(3),AccessibleName=text,AccessibleDescription=text};b.Click+=delegate{try{action();}catch(Exception ex){if(proof)throw;MessageBox.Show(this,ex.Message,"Taskbar Monitor",MessageBoxButtons.OK,MessageBoxIcon.Warning);}};return b;}
        private ComboBox Combo(IEnumerable<string> items,string name,int width=185){var c=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,Width=width,AccessibleName=name,AccessibleDescription=name,Margin=new Padding(4,6,4,4)};c.Items.AddRange(items.Cast<object>().ToArray());if(c.Items.Count>0)c.SelectedIndex=0;return c;}
        private CheckBox Check(string text,bool value){return new CheckBox{Text=text,Checked=value,AutoSize=true,Margin=new Padding(6,8,6,4),AccessibleName=text,AccessibleDescription=text};}
        private Label Note(string text,int height=44){return new Label{Text=text,Dock=DockStyle.Bottom,Height=height,Padding=new Padding(4),AutoEllipsis=true};}
        private DataGridView Grid(string name,params string[] headers)
        {
            var g=new DataGridView{Dock=DockStyle.Fill,ReadOnly=true,AllowUserToAddRows=false,AllowUserToDeleteRows=false,RowHeadersVisible=false,AutoSizeColumnsMode=DataGridViewAutoSizeColumnsMode.Fill,SelectionMode=DataGridViewSelectionMode.FullRowSelect,MultiSelect=false,BackgroundColor=Color.FromArgb(20,28,38),BorderStyle=BorderStyle.None,AccessibleName=name,AccessibleDescription=name,AllowUserToResizeRows=false};
            g.RowTemplate.Height=26;g.ColumnHeadersHeight=30;foreach(string h in headers)g.Columns.Add(h,h);g.DefaultCellStyle.NullValue="-";return g;
        }
        private NumericUpDown Number(int value,int min,int max,string name){return new NumericUpDown{Minimum=min,Maximum=max,Value=Math.Max(min,Math.Min(max,value)),Width=100,AccessibleName=name,AccessibleDescription=name,Margin=new Padding(4,6,8,4)};}
        private void Save(Action change){change();apply();ApplyPalette();status.Text="Saved. Existing startup and sensor settings are preserved.";}
        private void Export(string title,string filter,string file,Action<string> write)
        {using(var d=new SaveFileDialog{Title=title,Filter=filter,FileName=file,AddExtension=true,OverwritePrompt=true})if(d.ShowDialog(this)==DialogResult.OK){write(d.FileName);status.Text="Export saved locally: "+Path.GetFileName(d.FileName);}}
        private void BuildOverview()
        {
            var p=Page("Overview");var bar=Bar();metric=Combo(WorkspaceMetric.Names,"Chart metric",195);window=Combo(new[]{"Last 1 minute","Last 5 minutes","Last 15 minutes","Last 60 minutes","All session samples"},"History window",165);window.SelectedIndex=1;
            freezeChart=Check("Freeze chart",false);bar.Controls.AddRange(new Control[]{metric,window,freezeChart,Button("Pause / resume sampling",()=>setPaused(!paused())),Button("Export session CSV",()=>Export("Export session CSV","CSV files|*.csv","tbme-session.csv",path=>SessionTelemetryHistory.ExportCsv(path)))});
            var exports=Bar();exports.Controls.Add(Button("Save chart PNG",()=>Export("Save current chart","PNG image|*.png","tbme-chart.png",path=>{using(var b=new Bitmap(chart.Width,chart.Height)){chart.DrawToBitmap(b,chart.ClientRectangle);b.Save(path,ImageFormat.Png);}})));
            exports.Controls.Add(Button("Export statistics JSON",()=>Export("Export current statistics","JSON files|*.json","tbme-statistics.json",ExportStatistics)));
            stats=new Label{Dock=DockStyle.Top,Height=44,Padding=new Padding(6,10,0,0),Font=new Font("Segoe UI Semibold",10f)};chart=new HistoryChart{Dock=DockStyle.Fill,Font=Font};
            p.Controls.Add(chart);p.Controls.Add(stats);p.Controls.Add(exports);p.Controls.Add(bar);p.Controls.Add(Note("History: at most 3,600 observed samples. Percent charts use 0-100%; rates and temperatures auto-scale. Missing values and gaps over 30 seconds are not connected."));
            metric.SelectedIndexChanged+=delegate{RefreshOverview(true);};window.SelectedIndexChanged+=delegate{RefreshOverview(true);};freezeChart.CheckedChanged+=delegate{if(!freezeChart.Checked)RefreshOverview(true);};
        }
        private void RefreshOverview(bool force=false)
        {
            if(chart==null||(!force&&freezeChart.Checked))return;
            var samples=SessionTelemetryHistory.Snapshot();int[] minutes={1,5,15,60,0};int period=minutes[Math.Max(0,window.SelectedIndex)];
            DateTime cutoff=DateTime.UtcNow.AddMinutes(-period);chart.Samples=samples.Where(s=>period==0||s.Utc>=cutoff).OrderBy(s=>s.Utc).ToArray();chart.Metric=Math.Max(0,metric.SelectedIndex);
            var r=MetricStatistics.Calculate(chart.Samples.Select(s=>WorkspaceMetric.Value(s,chart.Metric)));
            stats.Text=r.Count==0?"No available samples for this metric.":String.Format(CultureInfo.InvariantCulture,"{0}   |   MIN {1:0.##}    MAX {2:0.##}    AVG {3:0.##}    P95 {4:0.##}   |   {5} samples",metric.SelectedItem,r.Minimum,r.Maximum,r.Average,r.P95,r.Count);chart.Invalidate();
        }
        private void ExportStatistics(string path)
        {
            var list=new List<object>();for(int i=0;i<WorkspaceMetric.Names.Length;i++){var r=MetricStatistics.Calculate(chart.Samples.Select(s=>WorkspaceMetric.Value(s,i)));list.Add(new{Metric=WorkspaceMetric.Names[i],r.Count,Minimum=r.Count>0?(double?)r.Minimum:null,Maximum=r.Count>0?(double?)r.Maximum:null,Average=r.Count>0?(double?)r.Average:null,P95=r.Count>0?(double?)r.P95:null});}
            File.WriteAllText(path,new JavaScriptSerializer().Serialize(new{Version=BuildInfo.PublicVersion,GeneratedUtc=DateTime.UtcNow.ToString("o"),Window=Convert.ToString(window.SelectedItem),Statistics=list}),new UTF8Encoding(false));
        }
        private void BuildProcesses()
        {
            var p=Page("Processes");var bar=Bar();processSearch=new TextBox{Width=220,AccessibleName="Filter processes by name or PID",Margin=new Padding(4,7,4,4)};processSort=Combo(new[]{"CPU descending","Working set descending","PID ascending","Name ascending"},"Process sort",180);freezeProcesses=Check("Freeze processes",false);
            bar.Controls.AddRange(new Control[]{new Label{Text="Filter",AutoSize=true,Padding=new Padding(0,9,0,0)},processSearch,processSort,freezeProcesses,Button("Export visible CSV",()=>Export("Export visible process list","CSV files|*.csv","tbme-processes.csv",path=>WorkspaceExport.Processes(path,VisibleProcesses()))),Button("Task Manager",()=>Process.Start(new ProcessStartInfo(Path.Combine(Environment.SystemDirectory,"Taskmgr.exe")){UseShellExecute=true}))});
            processes=Grid("Read-only process table","PID","Process","CPU %","Working set MiB","Private MiB","Threads","Handles");p.Controls.Add(processes);p.Controls.Add(bar);p.Controls.Add(Note("Read-only. Sampling runs only while this page is open. CPU is normalized across logical processors and needs two samples; protected or exited processes may be unavailable or omitted."));
            processSearch.TextChanged+=delegate{RenderProcesses();};processSort.SelectedIndexChanged+=delegate{RenderProcesses();};
        }
        private IEnumerable<ProcessRow> VisibleProcesses()
        {
            string q=processSearch.Text.Trim();IEnumerable<ProcessRow> r=processRows.Where(x=>q.Length==0||x.Name.IndexOf(q,StringComparison.OrdinalIgnoreCase)>=0||x.Pid.ToString().Contains(q));
            switch(processSort.SelectedIndex){case 1:return r.OrderByDescending(x=>x.WorkingSetMiB);case 2:return r.OrderBy(x=>x.Pid);case 3:return r.OrderBy(x=>x.Name,StringComparer.OrdinalIgnoreCase);default:return r.OrderByDescending(x=>x.CpuPercent??-1);}
        }
        private void RenderProcesses(){processes.Rows.Clear();foreach(var r in VisibleProcesses())processes.Rows.Add(r.Pid,r.Name,r.CpuPercent.HasValue?r.CpuPercent.Value.ToString("0.0"):"-",r.WorkingSetMiB.ToString("0.0"),r.PrivateMiB.ToString("0.0"),r.Threads,r.Handles);}
        private void PollProcesses()
        {
            if(freezeProcesses.Checked||proof||Interlocked.CompareExchange(ref processBusy,1,0)!=0)return;
            ThreadPool.QueueUserWorkItem(delegate{try{var rows=processSampler.Read(Stopwatch.GetTimestamp()/(double)Stopwatch.Frequency);if(IsDisposed||!IsHandleCreated)return;try{BeginInvoke((MethodInvoker)delegate{if(!IsDisposed&&!freezeProcesses.Checked&&tabs.SelectedTab.Text=="Processes"){processRows=rows;RenderProcesses();}});}catch(InvalidOperationException){} }catch(Exception ex){Log.Write("WARN","PROCESS_WORKSPACE_READ "+ex.GetType().Name);}finally{Interlocked.Exchange(ref processBusy,0);}});
        }
        private void BuildNetwork()
        {
            var p=Page("Network");var bar=Bar();adapterChoice=Combo(new[]{"Auto - pin one active adapter"},"Traffic accounting adapter",245);adapterIds.Add("");persistTraffic=Check("Keep 90 days locally",config.RecordTrafficHistory);bits=Check("Taskbar rates in bits/s",config.NetworkRateInBits);budget=Number(config.MonthlyTrafficBudgetGB,0,100000,"Monthly traffic budget in decimal GB");
            bar.Controls.AddRange(new Control[]{adapterChoice,persistTraffic,bits,new Label{Text="Budget GB (0=off)",AutoSize=true,Padding=new Padding(4,9,0,0)},budget,Button("Apply network options",()=>Save(()=>{config.RecordTrafficHistory=persistTraffic.Checked;config.NetworkRateInBits=bits.Checked;config.MonthlyTrafficBudgetGB=(int)budget.Value;config.TrafficAdapterId=adapterChoice.SelectedIndex>=0?adapterIds[adapterChoice.SelectedIndex]:"";}))});
            trafficSummary=new Label{Dock=DockStyle.Top,Height=64,Padding=new Padding(5)};var split=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=1,RowCount=2};split.RowStyles.Add(new RowStyle(SizeType.Percent,50));split.RowStyles.Add(new RowStyle(SizeType.Percent,50));
            network=Grid("Network adapters","Adapter","Download","Upload","Link Mbps","RX link %","TX link %");trafficDays=Grid("Daily observed traffic","Local date","Download GiB","Upload GiB","Total GiB");split.Controls.Add(network,0,0);split.Controls.Add(trafficDays,0,1);
            var bottom=Bar();bottom.Dock=DockStyle.Bottom;bottom.Controls.Add(Button("Export daily CSV",()=>Export("Export observed daily traffic","CSV files|*.csv","tbme-traffic.csv",traffic.ExportCsv)));
            p.Controls.Add(split);p.Controls.Add(trafficSummary);p.Controls.Add(bar);p.Controls.Add(bottom);p.Controls.Add(Note("Traffic is observed adapter-counter deltas, not an ISP bill. One pinned adapter avoids VPN + physical double counting. First samples, counter resets and gaps over 30s are excluded; intervals crossing midnight are assigned to the ending local date.",50));
        }
        private void RefreshNetwork(MetricsSnapshot s)
        {
            var devices=s.NetworkDevices??new List<NetworkDeviceSnapshot>();string signature=String.Join(";",devices.Select(n=>n.Id).ToArray());
            if(signature!=lastAdapterSignature){lastAdapterSignature=signature;adapterChoice.Items.Clear();adapterIds.Clear();adapterIds.Add("");adapterChoice.Items.Add("Auto - pin one active adapter");foreach(var d in devices){adapterIds.Add(d.Id);adapterChoice.Items.Add(d.Name);}if(!String.IsNullOrEmpty(config.TrafficAdapterId)&&!adapterIds.Contains(config.TrafficAdapterId)){adapterIds.Add(config.TrafficAdapterId);adapterChoice.Items.Add("Configured adapter (offline)");}adapterChoice.SelectedIndex=Math.Max(0,adapterIds.IndexOf(config.TrafficAdapterId??""));}
            network.Rows.Clear();foreach(var d in devices)network.Rows.Add(d.Name,FormatRate(d.DownBytesPerSec),FormatRate(d.UpBytesPerSec),(d.LinkSpeedBitsPerSec/1000000d).ToString("0.#"),d.LinkSpeedBitsPerSec>0?(100*d.DownBytesPerSec*8/d.LinkSpeedBitsPerSec).ToString("0.##"):"-",d.LinkSpeedBitsPerSec>0?(100*d.UpBytesPerSec*8/d.LinkSpeedBitsPerSec).ToString("0.##"):"-");
            var days=traffic.Snapshot();trafficDays.Rows.Clear();foreach(var d in days)trafficDays.Rows.Add(d.Day,(d.DownloadBytes/1073741824d).ToString("0.###"),(d.UploadBytes/1073741824d).ToString("0.###"),((d.DownloadBytes+d.UploadBytes)/1073741824d).ToString("0.###"));
            string month=DateTime.Now.ToString("yyyy-MM",CultureInfo.InvariantCulture);double total=days.Where(d=>d.Day.StartsWith(month,StringComparison.Ordinal)).Sum(d=>d.DownloadBytes+d.UploadBytes)/1e9;
            trafficSummary.Text="Accounting adapter: "+traffic.ActiveAdapterName+"   |   Session: "+UnitFormatter.Bytes(traffic.SessionDownload+traffic.SessionUpload,"Auto")+"\nObserved this month: "+total.ToString("0.###")+" GB"+(config.MonthlyTrafficBudgetGB>0?" / "+config.MonthlyTrafficBudgetGB+" GB ("+(100*total/config.MonthlyTrafficBudgetGB).ToString("0.0")+"%)":"   |   No budget configured")+(traffic.LastError==null?"":"   |   "+traffic.LastError);
        }
        private string FormatRate(double bytes){return config.NetworkRateInBits?NetworkRateFormatter.Bits(bytes):UnitFormatter.Rate(bytes,"Auto");}
        private void BuildStorage(){var p=Page("Storage");storage=Grid("Disk capacity and activity","Device","Volumes","Used %","Free GiB","Total GiB","Read MiB/s","Write MiB/s","Temperature C");p.Controls.Add(storage);p.Controls.Add(Note("Unavailable data is shown as '-'. Capacity refers to mapped volumes, not raw physical-disk health. No SMART health score or disk-repair action is inferred."));}
        private void RefreshStorage(MetricsSnapshot s){storage.Rows.Clear();foreach(var d in s.DiskDevices){int i=storage.Rows.Add(d.Name,d.Volumes,d.CapacityAvailable?d.UsedPercent.ToString("0.0"):"-",d.CapacityAvailable?((d.TotalBytes-Math.Min(d.TotalBytes,d.UsedBytes))/1073741824d).ToString("0.0"):"-",d.CapacityAvailable?(d.TotalBytes/1073741824d).ToString("0.0"):"-",d.RateAvailable?(d.ReadBytesPerSec/1048576d).ToString("0.##"):"-",d.RateAvailable?(d.WriteBytesPerSec/1048576d).ToString("0.##"):"-",d.TemperatureAvailable?d.Temperature.ToString("0.0"):"-");if(d.CapacityAvailable&&d.UsedPercent>=config.DiskSpaceWarningPercent)storage.Rows[i].DefaultCellStyle.ForeColor=SystemInformation.HighContrast?SystemColors.Highlight:Color.FromArgb(235,106,86);}}
        private void BuildAlerts()
        {
            var p=Page("Alerts");var bar=Bar();usageEnabled=Check("Enable sustained usage notifications",config.EnableUsageNotifications);quietEnabled=Check("Quiet hours (Windows local time)",config.QuietHoursEnabled);bar.Controls.AddRange(new Control[]{usageEnabled,quietEnabled,Button("Snooze all for 30 min",()=>{snooze();status.Text="All notifications snoozed for 30 minutes.";})});
            var options=Bar();cpuWarn=Number(config.CpuUsageWarningPercent,50,100,"CPU usage threshold percent");ramWarn=Number(config.RamUsageWarningPercent,50,100,"RAM usage threshold percent");gpuWarn=Number(config.GpuUsageWarningPercent,50,100,"GPU usage threshold percent");diskWarn=Number(config.DiskSpaceWarningPercent,50,100,"Disk capacity threshold percent");
            foreach(var pair in new[]{Tuple.Create("CPU %",cpuWarn),Tuple.Create("RAM %",ramWarn),Tuple.Create("GPU %",gpuWarn),Tuple.Create("Disk used %",diskWarn)}){options.Controls.Add(new Label{Text=pair.Item1,AutoSize=true,Padding=new Padding(2,9,0,0)});options.Controls.Add(pair.Item2);}
            var timing=Bar();dwell=Number(config.SustainedAlertSeconds,5,300,"Minimum sustained seconds");cooldown=Number(config.UsageAlertCooldownMinutes,1,120,"Usage alert cooldown minutes");quietStart=Number(config.QuietHoursStart,0,23,"Quiet hours start hour");quietEnd=Number(config.QuietHoursEnd,0,23,"Quiet hours end hour");
            foreach(var pair in new[]{Tuple.Create("Sustained seconds",dwell),Tuple.Create("Cooldown minutes",cooldown),Tuple.Create("Quiet start hour",quietStart),Tuple.Create("End hour",quietEnd)}){timing.Controls.Add(new Label{Text=pair.Item1,AutoSize=true,Padding=new Padding(2,9,0,0)});timing.Controls.Add(pair.Item2);}
            var actions=Bar();actions.Controls.Add(Button("Save alert policy",()=>Save(()=>{config.EnableUsageNotifications=usageEnabled.Checked;config.QuietHoursEnabled=quietEnabled.Checked;config.CpuUsageWarningPercent=(int)cpuWarn.Value;config.RamUsageWarningPercent=(int)ramWarn.Value;config.GpuUsageWarningPercent=(int)gpuWarn.Value;config.DiskSpaceWarningPercent=(int)diskWarn.Value;config.SustainedAlertSeconds=(int)dwell.Value;config.UsageAlertCooldownMinutes=(int)cooldown.Value;config.QuietHoursStart=(int)quietStart.Value;config.QuietHoursEnd=(int)quietEnd.Value;})));
            actions.Controls.Add(Button("Export event CSV",()=>Export("Export alert events","CSV files|*.csv","tbme-alerts.csv",path=>{var b=new StringBuilder("Utc,Metric,Message\r\n");foreach(var a in alerts())b.AppendLine(a.Utc.ToString("o")+","+WorkspaceExport.CsvCell(a.Metric)+","+WorkspaceExport.CsvCell(a.Message));File.WriteAllText(path,b.ToString(),new UTF8Encoding(false));})));
            events=Grid("Bounded alert event history","UTC time","Metric","Message");events.Columns[2].FillWeight=250;p.Controls.Add(events);p.Controls.Add(actions);p.Controls.Add(timing);p.Controls.Add(options);p.Controls.Add(bar);p.Controls.Add(Note("Up to 200 events in memory. Usage alerts rearm after cooling 5 percentage points. Equal quiet start/end means quiet all day. Temperature thresholds remain in Settings > Alerts; quiet hours and snooze cover both types.",48));
        }
        private void BuildThemes()
        {
            var p=Page("Themes");var bar=Bar();themeSearch=new TextBox{Width=240,AccessibleName="Search themes",Margin=new Padding(4,7,4,4)};themeFilter=Combo(new[]{"All 48 themes","20 Studio themes","Favorites","Light themes","Dark themes"},"Theme filter",200);bar.Controls.AddRange(new Control[]{new Label{Text="Search",AutoSize=true,Padding=new Padding(0,9,0,0)},themeSearch,themeFilter});
            var body=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=2,RowCount=1};body.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,255));body.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));themes=new ListBox{Dock=DockStyle.Fill,IntegralHeight=false,AccessibleName="Theme catalog",DrawMode=DrawMode.OwnerDrawFixed,ItemHeight=26};var right=new Panel{Dock=DockStyle.Fill,Padding=new Padding(15,0,0,0)};
            preview=new ThemePreviewControl(render){Dock=DockStyle.Top,AccessibleName="Production renderer theme preview"};themeInfo=new Label{Dock=DockStyle.Top,Height=100,Padding=new Padding(4,14,0,0)};var buttons=Bar();buttons.Dock=DockStyle.Bottom;
            buttons.Controls.Add(Button("Apply selected theme",()=>{if(themes.SelectedItem==null)return;Save(()=>{config.Theme=Convert.ToString(themes.SelectedItem);config.FollowWindowsTheme=false;});UpdateThemeInfo();}));
            buttons.Controls.Add(Button("Toggle favorite",()=>{if(themes.SelectedItem==null)return;string name=Convert.ToString(themes.SelectedItem);Save(()=>{var f=SelectionUtil.Parse(config.FavoriteThemes);if(!f.Add(name))f.Remove(name);config.FavoriteThemes=SelectionUtil.Join(f);});RefreshThemeList(name);}));
            right.Controls.Add(themeInfo);right.Controls.Add(preview);right.Controls.Add(buttons);right.Controls.Add(Note("This preview uses the real taskbar renderer and observed metrics. Apply selects manual theme mode; it never alters sensor configuration. Every Studio design uses its own frame geometry, not just a recolored palette.",62));body.Controls.Add(themes,0,0);body.Controls.Add(right,1,0);p.Controls.Add(body);p.Controls.Add(bar);
            themeSearch.TextChanged+=delegate{RefreshThemeList();};themeFilter.SelectedIndexChanged+=delegate{RefreshThemeList();};themes.DrawItem+=DrawThemeListItem;themes.SelectedIndexChanged+=delegate{UpdateThemeInfo();};RefreshThemeList(config.Theme);
        }
        private void RefreshThemeList(string select=null)
        {
            string current=select??Convert.ToString(themes.SelectedItem);var favorites=SelectionUtil.Parse(config.FavoriteThemes);themes.BeginUpdate();themes.Items.Clear();
            foreach(string n in ThemeCatalog.Names){var t=ThemeCatalog.Get(n);if(n.IndexOf(themeSearch.Text.Trim(),StringComparison.OrdinalIgnoreCase)<0)continue;if(themeFilter.SelectedIndex==1&&!StudioThemes.IsStudio(t.Mode)||themeFilter.SelectedIndex==2&&!favorites.Contains(n)||themeFilter.SelectedIndex==3&&!t.Light||themeFilter.SelectedIndex==4&&t.Light)continue;themes.Items.Add(n);}
            if(themes.Items.Contains(current))themes.SelectedItem=current;else if(themes.Items.Count>0)themes.SelectedIndex=0;themes.EndUpdate();UpdateThemeInfo();
        }
        private void UpdateThemeInfo(){if(themes.SelectedItem==null){themeInfo.Text="No themes match the filter.";return;}string name=Convert.ToString(themes.SelectedItem);var t=ThemeCatalog.Get(name);preview.ThemeName=name;themeInfo.Text=name+"\n"+(t.Light?"Light":"Dark")+"  /  "+t.Mode+"  /  "+t.FontName+"\n"+(SelectionUtil.Parse(config.FavoriteThemes).Contains(name)?"Favorite":"Not in favorites")+"  |  Current manual choice: "+config.Theme;}
        private void BuildProfiles()
        {
            var p=Page("Profiles");var bar=Bar();bar.Controls.Add(Button("Export presentation",()=>Export("Export presentation profile","JSON files|*.json","tbme-presentation.json",path=>File.WriteAllText(path,WorkspaceExport.Profile(config),new UTF8Encoding(false)))));
            bar.Controls.Add(Button("Import presentation",()=>{using(var d=new OpenFileDialog{Filter="JSON files|*.json",CheckFileExists=true})if(d.ShowDialog(this)==DialogResult.OK){SafeResetPolicy.BackupCurrentConfig(AppPaths.Config,Path.Combine(AppPaths.Root,"ProfileBackups"),DateTime.Now);WorkspaceExport.ImportProfile(config,d.FileName);apply();order.Items.Clear();order.Items.AddRange(config.MetricOrder.Split(';'));ApplyPalette();RefreshThemeList(config.Theme);status.Text="Presentation imported. Prior configuration backed up; startup and sensors unchanged.";}}));
            var presets=Bar();foreach(string preset in new[]{"Balanced","Focus","Network desk","GPU workstation"}){string selected=preset;presets.Controls.Add(Button(selected,()=>{Save(()=>{config.ShowCpu=true;config.ShowRam=true;config.ShowDisk=selected=="Balanced";config.ShowGpu=selected=="Balanced"||selected=="GPU workstation";config.ShowVram=config.ShowGpu;config.ShowNetwork=selected=="Balanced"||selected=="Network desk";config.ShowSparklines=selected!="Focus";});}));}
            order=new ListBox{Dock=DockStyle.Left,Width=250,IntegralHeight=false,AccessibleName="Taskbar metric order"};order.Items.AddRange(config.MetricOrder.Split(';'));order.SelectedIndex=0;var controls=Bar();controls.Dock=DockStyle.Top;
            controls.Controls.Add(Button("Move up",()=>MoveOrder(-1)));controls.Controls.Add(Button("Move down",()=>MoveOrder(1)));controls.Controls.Add(Button("Apply order",()=>Save(()=>{config.MetricOrder=String.Join(";",order.Items.Cast<string>().ToArray());})));
            var body=new Panel{Dock=DockStyle.Fill,Padding=new Padding(0,10,0,0)};body.Controls.Add(order);var right=new Panel{Dock=DockStyle.Fill,Padding=new Padding(15)};right.Controls.Add(controls);right.Controls.Add(Note("Presentation profiles contain only theme, visible metrics, ordering, font size, opacity, units and graph options. They cannot change startup, sensor paths, notification permissions, traffic retention or execute commands.",90));body.Controls.Add(right);right.BringToFront();p.Controls.Add(body);p.Controls.Add(presets);p.Controls.Add(bar);p.Controls.Add(Note("Move taskbar groups without changing their per-device selection. Profiles preserve your hardware, temperature thresholds and Start-with-Windows configuration."));
        }
        private void MoveOrder(int delta){int i=order.SelectedIndex,j=i+delta;if(i<0||j<0||j>=order.Items.Count)return;object value=order.Items[i];order.Items.RemoveAt(i);order.Items.Insert(j,value);order.SelectedIndex=j;}
        private void BuildHardware()
        {
            var p=Page("Hardware");var bar=Bar();
            hardwareSearch=new TextBox{Width=250,AccessibleName="Filter hardware inventory",Margin=new Padding(4,7,4,4)};
            bar.Controls.AddRange(new Control[]{new Label{Text="Filter",AutoSize=true,Padding=new Padding(0,9,0,0)},hardwareSearch,
                Button("Export visible CSV",()=>Export("Export visible hardware inventory","CSV files|*.csv","tbme-hardware.csv",path=>HardwareInventory.ExportCsv(path,VisibleHardware()))),
                Button("Export inventory JSON",()=>Export("Export hardware inventory","JSON files|*.json","tbme-hardware.json",path=>File.WriteAllText(path,new JavaScriptSerializer().Serialize(new{Version=BuildInfo.PublicVersion,GeneratedUtc=DateTime.UtcNow.ToString("o"),Rows=hardwareRows}),new UTF8Encoding(false))))});
            hardwareSummary=new Label{Dock=DockStyle.Top,Height=44,Padding=new Padding(5,9,0,0)};
            hardware=Grid("Available hardware sensor and inventory data","Group","Device","Metric","Value","Unit","Status");
            hardware.Columns[0].FillWeight=65;hardware.Columns[1].FillWeight=190;hardware.Columns[2].FillWeight=175;
            hardware.Columns[3].FillWeight=105;hardware.Columns[4].FillWeight=60;hardware.Columns[5].FillWeight=85;
            p.Controls.Add(hardware);p.Controls.Add(hardwareSummary);p.Controls.Add(bar);
            p.Controls.Add(Note("Values reuse the protected, process-isolated telemetry snapshot. Static inventory and reported CPU clocks are cached; unavailable sensors stay blank, not zero. No extra driver, network request or privileged action is triggered by this page.",48));
            hardwareSearch.TextChanged+=delegate{RenderHardware();};
        }
        private IEnumerable<HardwareRow> VisibleHardware()
        {
            string q=hardwareSearch.Text.Trim();return hardwareRows.Where(r=>q.Length==0||(r.Group+" "+r.Device+" "+r.Metric).IndexOf(q,StringComparison.OrdinalIgnoreCase)>=0);
        }
        private void RenderHardware()
        {
            int first=hardware.FirstDisplayedScrollingRowIndex;hardware.Rows.Clear();
            foreach(var r in VisibleHardware())hardware.Rows.Add(r.Group,r.Device,r.Metric,String.IsNullOrEmpty(r.Value)?"-":r.Value,r.Unit,r.Status);
            if(first>=0&&first<hardware.Rows.Count)try{hardware.FirstDisplayedScrollingRowIndex=first;}catch(InvalidOperationException){}
        }
        private void RefreshHardware(MetricsSnapshot s)
        {
            hardwareRows=HardwareInventory.Read(s);RenderHardware();
            var power=SystemInformation.PowerStatus;string battery;
            if(power.BatteryChargeStatus==BatteryChargeStatus.Unknown)battery="unknown";
            else if((power.BatteryChargeStatus&BatteryChargeStatus.NoSystemBattery)!=0)battery="not present";
            else battery=power.BatteryLifePercent>=0?(power.BatteryLifePercent*100).ToString("0",CultureInfo.InvariantCulture)+"%":"unknown";
            hardwareSummary.Text=hardwareRows.Count+" sensor/inventory rows   |   Power: "+power.PowerLineStatus+"   Battery: "+battery+"   |   "+(Environment.Is64BitProcess?"64-bit":"32-bit")+" monitor   |   DPI: "+Native.DpiAwarenessMode();
        }
        private void DrawThemeListItem(object sender,DrawItemEventArgs e)
        {
            if(e.Index<0||e.Index>=themes.Items.Count)return;
            var palette=WindowsThemePolicy.Resolve(config);string name=Convert.ToString(themes.Items[e.Index]);var choice=ThemeCatalog.Get(name);
            bool selected=(e.State&DrawItemState.Selected)!=0;
            using(var bg=new SolidBrush(selected?palette.Background2:palette.Background))e.Graphics.FillRectangle(bg,e.Bounds);
            using(var swatch=new SolidBrush(choice.Accents[0]))e.Graphics.FillRectangle(swatch,e.Bounds.X+4,e.Bounds.Y+5,4,Math.Max(1,e.Bounds.Height-10));
            string text=(SelectionUtil.Parse(config.FavoriteThemes).Contains(name)?"* ":"")+name;
            TextRenderer.DrawText(e.Graphics,text,Font,new Rectangle(e.Bounds.X+14,e.Bounds.Y,e.Bounds.Width-17,e.Bounds.Height),palette.Foreground,TextFormatFlags.Left|TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis);
            if((e.State&DrawItemState.Focus)!=0)e.DrawFocusRectangle();
        }
        private static IEnumerable<Control> Descendants(Control root)
        {
            foreach(Control child in root.Controls){yield return child;foreach(Control nested in Descendants(child))yield return nested;}
        }
        private void ProofClick(string page,string label)
        {
            SelectPage(page);Application.DoEvents();
            var button=Descendants(tabs.SelectedTab).OfType<Button>().SingleOrDefault(b=>b.Text==label);
            if(button==null||!button.Enabled||!button.Visible)throw new InvalidOperationException("Action not reachable: "+page+" / "+label);
            button.PerformClick();Application.DoEvents();
        }
        internal Dictionary<string,object> VerifyActualActions(Func<string[]> metricKeys,Func<string> networkText)
        {
            if(!proof)throw new InvalidOperationException("Isolated proof form required.");
            var json=new JavaScriptSerializer();AppConfig previous=json.Deserialize<AppConfig>(json.Serialize(config));
            var passed=new List<string>();Action<bool,string> verify=(condition,name)=>{if(!condition)throw new InvalidOperationException("UI action failed: "+name);passed.Add(name);};
            try
            {
                SelectPage("Themes");themeFilter.SelectedIndex=0;themeSearch.Text="";verify(themes.Items.Count==48,"all 48 themes reachable");
                themeFilter.SelectedIndex=1;verify(themes.Items.Count==20,"20 Studio filter");
                themeFilter.SelectedIndex=0;themeSearch.Text="swiss";verify(themes.Items.Count==1&&Convert.ToString(themes.Items[0])=="Swiss Grid","case-insensitive theme search");
                themes.SelectedIndex=0;ProofClick("Themes","Apply selected theme");verify(config.Theme=="Swiss Grid"&&!config.FollowWindowsTheme,"theme apply and manual mode");
                ProofClick("Themes","Toggle favorite");verify(SelectionUtil.Parse(config.FavoriteThemes).Contains("Swiss Grid"),"favorite persisted in configuration");
                themeFilter.SelectedIndex=2;verify(themes.Items.Count==1,"favorites filter");
                ProofClick("Profiles","Focus");verify(metricKeys().SequenceEqual(new[]{"CPU","RAM"}),"Focus preset reaches actual renderer");
                ProofClick("Profiles","Balanced");verify(metricKeys().Length==6,"Balanced preset restores all six groups");
                order.SelectedIndex=5;ProofClick("Profiles","Move up");ProofClick("Profiles","Apply order");
                verify(metricKeys()[4]=="NET"&&metricKeys()[5]=="VRAM","order buttons change actual rendered order");
                SelectPage("Network");bits.Checked=true;ProofClick("Network","Apply network options");
                verify(config.NetworkRateInBits&&networkText().Contains("bit/s"),"bit-rate option reaches actual taskbar labels");
                SelectPage("Alerts");usageEnabled.Checked=true;cpuWarn.Value=90;dwell.Value=15;ProofClick("Alerts","Save alert policy");
                verify(config.EnableUsageNotifications&&config.CpuUsageWarningPercent==90&&config.SustainedAlertSeconds==15,"alert controls save policy");
                ProofClick("Overview","Pause / resume sampling");verify(paused(),"pause action callback");ProofClick("Overview","Pause / resume sampling");verify(!paused(),"resume action callback");
                SelectPage("Hardware");RefreshHardware(live());hardwareSearch.Text="GPU";verify(VisibleHardware().All(r=>(r.Group+" "+r.Device+" "+r.Metric).IndexOf("GPU",StringComparison.OrdinalIgnoreCase)>=0),"hardware filter");
                verify(config.StartWithWindows==previous.StartWithWindows&&config.RecordTrafficHistory==previous.RecordTrafficHistory&&config.EnableTemperatureNotifications==previous.EnableTemperatureNotifications,"visual/workspace actions preserve protected preferences");
                int names=0,gaps=0;foreach(var c in Descendants(this)){if(c is Button||c is ComboBox||c is CheckBox||c is NumericUpDown||c is ListBox||c is TextBox){names++;if(String.IsNullOrWhiteSpace(c.AccessibleName))gaps++;}}
                verify(gaps==0,"interactive accessibility names");
                return new Dictionary<string,object>{{"Status","PASS"},{"Checks",passed.ToArray()},{"Count",passed.Count},{"InteractiveControls",names},{"AccessibilityNameGaps",gaps}};
            }
            finally
            {
                foreach(var p in typeof(AppConfig).GetProperties())if(p.CanRead&&p.CanWrite)p.SetValue(config,p.GetValue(previous,null),null);
                bits.Checked=config.NetworkRateInBits;persistTraffic.Checked=config.RecordTrafficHistory;budget.Value=config.MonthlyTrafficBudgetGB;
                usageEnabled.Checked=config.EnableUsageNotifications;cpuWarn.Value=config.CpuUsageWarningPercent;dwell.Value=config.SustainedAlertSeconds;
                order.Items.Clear();order.Items.AddRange(config.MetricOrder.Split(';'));order.SelectedIndex=0;
                hardwareSearch.Text="";themeSearch.Text="";themeFilter.SelectedIndex=1;RefreshThemeList(config.Theme);ApplyPalette();SelectPage("Overview");
            }
        }

        private void RefreshPage()
        {
            if(IsDisposed)return;var s=live();if(s==null)return;
            string page=tabs.SelectedTab.Text;switch(page){case "Overview":RefreshOverview();break;case "Processes":PollProcesses();break;case "Network":RefreshNetwork(s);break;case "Storage":RefreshStorage(s);break;case "Alerts":events.Rows.Clear();foreach(var a in alerts())events.Rows.Add(a.Utc.ToString("yyyy-MM-dd HH:mm:ss"),a.Metric,a.Message);break;case "Themes":preview.Invalidate();break;case "Hardware":RefreshHardware(s);break;}
            status.Text=(paused()?"SAMPLING PAUSED":"LIVE")+"   |   "+SessionTelemetryHistory.Count+" / 3600 session samples   |   F5 refresh   Ctrl+1..8 pages   Esc close";
        }
        private void ApplyPalette()
        {
            ThemeDefinition t=WindowsThemePolicy.Resolve(config);tabs.Palette=t;tabs.Invalidate();Action<Control> visit=null;visit=c=>{c.BackColor=t.Background;c.ForeColor=t.Foreground;
                var button=c as Button;if(button!=null){button.FlatStyle=FlatStyle.Flat;button.FlatAppearance.BorderColor=t.Border;button.BackColor=t.Background2;}
                var grid=c as DataGridView;if(grid!=null){grid.BackgroundColor=t.Background;grid.GridColor=t.Border;grid.EnableHeadersVisualStyles=false;grid.ColumnHeadersDefaultCellStyle.BackColor=t.Background2;grid.ColumnHeadersDefaultCellStyle.ForeColor=t.Foreground;grid.ColumnHeadersDefaultCellStyle.SelectionBackColor=t.Background2;grid.ColumnHeadersDefaultCellStyle.SelectionForeColor=t.Foreground;grid.DefaultCellStyle.BackColor=t.Background;grid.DefaultCellStyle.ForeColor=t.Foreground;grid.DefaultCellStyle.SelectionBackColor=SystemInformation.HighContrast?SystemColors.Highlight:t.Background2;grid.DefaultCellStyle.SelectionForeColor=SystemInformation.HighContrast?SystemColors.HighlightText:t.Foreground;grid.AlternatingRowsDefaultCellStyle.BackColor=t.Background2;}
                if((c is Button||c is ComboBox||c is TextBox||c is CheckBox||c is NumericUpDown||c is ListBox||c is TabControl)&&String.IsNullOrEmpty(c.AccessibleName))c.AccessibleName=String.IsNullOrEmpty(c.Text)?c.GetType().Name:c.Text;
                foreach(Control child in c.Controls)visit(child);
            };visit(this);if(chart!=null){chart.Theme=t;chart.Invalidate();}
        }
        internal void NotifySystemPreferenceChanged(){if(!IsDisposed)ApplyPalette();}
        internal void PrepareProofProcesses()
        {
            processSampler.Read(Stopwatch.GetTimestamp()/(double)Stopwatch.Frequency);Thread.Sleep(200);
            processRows=processSampler.Read(Stopwatch.GetTimestamp()/(double)Stopwatch.Frequency);
            RenderProcesses();
            if(themeFilter!=null){themeFilter.SelectedIndex=1;if(themes.Items.Contains("Art Deco Gold"))themes.SelectedItem="Art Deco Gold";}
        }        internal void CapturePages(string dir)
        {Directory.CreateDirectory(dir);foreach(TabPage p in tabs.TabPages){tabs.SelectedTab=p;RefreshPage();Application.DoEvents();using(var b=new Bitmap(Width,Height)){DrawToBitmap(b,new Rectangle(Point.Empty,Size));b.Save(Path.Combine(dir,p.Text.ToLowerInvariant()+".png"),ImageFormat.Png);}}}
    }
    internal static class NetworkRateFormatter
    {
        internal static string Bits(double bytes){if(!MetricStatistics.Finite(bytes))return "-";double bits=Math.Max(0,bytes)*8;string unit="bit/s";if(bits>=1e9){bits/=1e9;unit="Gbit/s";}else if(bits>=1e6){bits/=1e6;unit="Mbit/s";}else if(bits>=1e3){bits/=1e3;unit="kbit/s";}return bits.ToString(bits>=100?"0":bits>=10?"0.0":"0.00",CultureInfo.InvariantCulture)+" "+unit;}
    }
}
