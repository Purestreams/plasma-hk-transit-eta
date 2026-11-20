# Hong Kong Transit Departures / 香港交通出发提醒 / 香港交通出發提醒

A KDE Plasma 6 widget for multiple selected KMB/LWB, Citybus or New Lantao Bus routes and stops, plus train times for the Airport Express, Tung Chung, Tsuen Wan and Island lines. It refreshes every 30 seconds. Interface languages: English, 简体中文 and 繁體中文, with a system-language option. Each widget instance stores multiple bus routes with separate walking times.

## Install

Requires Plasma 6, network access, and the standard Plasma QML components and the KNotifications QML module (`org.kde.notification`). From this folder:

```sh
kpackagetool6 --type Plasma/Applet --install .
# To update an existing installation:
kpackagetool6 --type Plasma/Applet --upgrade .
```

Enter desktop edit mode → Add Widgets → search for “Hong Kong Transit Departures” (or its translated name). Open **Settings** to select the language, enter walking minutes, and search the route number across KMB/LWB, Citybus and New Lantao Bus, then select an operator, direction and stop from the results. Repeat to add more buses and set each walking time under Saved bus stops. Remove any bus or MTR entry using the Remove button next to it; removal is saved immediately. Citybus matches require the full route number; KMB/LWB and New Lantao Bus also support partial matches. Add MTR entries by choosing a line, station and direction, then set a separate walking time for each entry and, if desired, a destination to exclude short-turn trains. The standard terminus is not repeated beside each arrival; short-turn destinations remain visible. Existing Hong Kong station settings migrate automatically. To apply an update to an already running Plasma session, remove and re-add the widget or restart the Plasma shell. Configuration belongs to the widget instance. Each bus entry names its stop and has its own walking time; adding a new entry leaves its walking time unset. An existing single-bus configuration is migrated on first load.

## Departure estimates

A published ETA takes priority. If none of the available MTR times can be reached and there are at least two usable, regularly spaced upcoming times, the widget extrapolates the median observed headway until it reaches the walking-time threshold. The extrapolated result is clearly marked **EST.**, **预估** or **預估**. It is an inference, not a published service, and can be wrong or cancelled. It does not account for disruptions, boarding, interchange, service changes or waiting to enter the station. The optional global buffer is added to each walking time. Upcoming real services may trigger a desktop notification when departure is within one minute; this can be disabled in Settings. Estimated services do not trigger notifications.

No extrapolation is made during a reported disruption, around the first/last trains (before 06:00 or from 23:00 Hong Kong time), if intervals are outside 2–30 minutes, when data is stale or missing, or beyond a 90-minute horizon. New Lantao Bus departures may use the same extrapolation and are marked as estimates; KMB/LWB and Citybus departures are not extrapolated. Each entry shows its data timestamp. API failure or source data older than 150 seconds warns that times are unreliable and suspends departure advice and notifications. Service notices appear beside arrivals; routine “scheduled service” and “not yet departed” remarks are hidden. The API publishes only a small number of imminent trains; an estimate must not be taken as proof that a later train exists. Check operator information for actual service.

## Data and attribution

- [KMB/LWB real-time arrivals](https://data.gov.hk/en-data/dataset/hk-td-tis_21-etakmb), disseminated by the Transport Department using data provided by KMB/LWB.
- [New Lantao Bus real-time service](https://data.gov.hk/en-data/dataset/nlb-bus-nlb-bus-service-v2).
- [Citybus real-time arrival API](https://www.citybus.com.hk/datagovhk/bus_eta_api_specifications.pdf).
- [MTR real-time train information](https://data.gov.hk/en-data/dataset/mtr-data2-nexttrain-data), provided by MTR Corporation Limited through DATA.GOV.HK.

Data ownership and applicable [DATA.GOV.HK terms](https://data.gov.hk/en/terms-and-conditions) remain with the Government and relevant organisations. The MIT licence applies to this widget's source code, not the transport data or operator marks. Route and stop requests are sent to the respective API endpoints; no analytics or account is included.

## Develop and test

The widget is QML with JavaScript modules in `contents/code/`. A new desktop instance defaults to 420 × 600 logical pixels, with scrolling when content exceeds the available area. Run `node tests/test.js` for the headway calculation, boundary conditions, live-data precedence and translation-key coverage. An optional live A12 QML integration test uses PySide6 and Qt/Plasma QML modules: `QT_QPA_PLATFORM=offscreen /usr/bin/python3 tests/integration_qml.py`. It uses an isolated mock configuration and real network APIs. Test the interface on a Plasma 6 desktop with the widget at different sizes. Data endpoints can be unavailable or return partial results.

## 简体中文

安装后在桌面编辑模式的「添加小组件」中搜索「香港交通出发提醒」。点击「设置」，选择语言、填写步行时间并输入路线号后同时搜索九巴／龙运、城巴及屿巴，再选择结果及站点；可重复添加多条路线并分别填写步行时间，三家公司均支持部分路线号搜索。港铁支持机场快线、东涌线、荃湾线及港岛线；每条线路、上车站和方向可分别设置步行时间。每条巴士记录独立显示站点及步行时间；新添加的记录需要填写步行时间。在设置中点击记录旁的「移除」可删除巴士或港铁记录。可为港铁选择目的地，过滤无法到达该站的短途列车；可设置额外缓冲和出发通知。每 30 秒刷新，数据过旧或失败时暂停出发建议。

当实时接口没有能赶上的港铁班次时，小组件可按最近班距外推，结果标记为「预估」。预估不是时刻表，不保证班次存在；延误、深夜、班距异常或数据不足时不会推算。请自行预留步行及进站缓冲，并以运营商公告为准。屿巴可按间隔预估，九巴／龙运和城巴不做间隔推算。

## 繁體中文

安裝後，在桌面編輯模式的「新增元件」中搜尋「香港交通出發提醒」。按「設定」選擇語言、填寫步行時間及輸入路線號後同時搜尋九巴／龍運、城巴及嶼巴，再選擇結果及車站；可重複新增多條路線並分別填寫步行時間，三間公司均支援部分路線號搜尋。港鐵支援機場快綫、東涌綫、荃灣綫及港島綫；每條路線、上車站及方向可分別設定步行時間。每條巴士記錄獨立顯示車站及步行時間；新增記錄需填寫步行時間。在設定中按記錄旁的「移除」可刪除巴士或港鐵記錄。可為港鐵選擇目的地以篩選短途列車，並設定額外緩衝及出發通知。每 30 秒更新，資料過舊或更新失敗時會暫停出發建議。

當即時介面沒有可趕上的港鐵班次時，小工具可按最近班距外推，結果標記為「預估」。預估不是時間表，不能保證班次存在；延誤、深夜、班距異常或資料不足時不會推算。請自行預留步行及入閘緩衝，並以營運商公告為準。嶼巴可按班距預估，九巴／龍運及城巴不作班距推算。
