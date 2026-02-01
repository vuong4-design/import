Plan triển khai Universal StoreKit Hook - Từng bước

Phase 1: Foundation & Safety (Tuần 1)
Bước 1.1: Refactor cấu trúc project

Tách riêng Universal hooks ra file UniversalStoreKitHooks.xm
Tách Game-specific hooks thành modules độc lập
Tạo TweakManager để điều phối init các hooks
Tạo Config.plist cho whitelist bundle IDs

Bước 1.2: Implement safe injection timing

Hook UIWindowDidBecomeKeyNotification để detect UI ready
Implement retry mechanism với exponential backoff
Add validation check: UIWindow exists, rootViewController exists
Test với 3-4 apps khác nhau để verify không crash

Bước 1.3: Bundle ID filtering

Load whitelist từ Config.plist
Check bundle ID trước khi init bất kỳ hook nào
Log apps được enable/disable để debug
Thêm toggle "Enable for all apps" trong settings


Phase 2: Observer Management (Tuần 2)
Bước 2.1: Observer tracking system

Tạo ObserverManager singleton
Hook addTransactionObserver: để track tất cả observers
Lưu observer class name + timestamp
Log ra console để debug conflicts

Bước 2.2: Priority-based handling

Assign priority cho VBStoreKitManager (priority = 0)
App observers tự động có priority = 10
Implement transaction routing theo priority
Test với app có sẵn multiple observers (game lớn)

Bước 2.3: Export/Import mode switching

Export mode: VBStoreKitManager xử lý, block app observers
Import mode: Cho app observers xử lý bình thường
Add UI toggle trong AppViewController
Test cả 2 modes với real IAP


Phase 3: Custom Wrapper Detection (Tuần 3)
Bước 3.1: Runtime class enumeration

Trong %ctor, enumerate tất cả classes
Filter classes conform to SKPaymentTransactionObserver
Log ra danh sách để xem app dùng class nào
Test với 5-6 apps phổ biến (YouTube, Telegram, Spotify...)

Bước 3.2: Dynamic hooking

Với mỗi class tìm được, hook paymentQueue:updatedTransactions:
Use method swizzling để inject logic
Giữ reference đến original IMP
Fallback về universal hook nếu không tìm thấy class nào

Bước 3.3: Network layer fallback

Hook NSURLSession để detect receipt validation requests
Intercept requests đến buy.itunes.apple.com/verifyReceipt
Parse response để extract transaction info
Dùng làm backup method khi StoreKit hook fails


Phase 4: Performance Optimization (Tuần 4)
Bước 4.1: Lazy initialization

Không init hooks ngay lúc app launch
Delay init đến khi user actually vào IAP screen
Hook UIViewController viewDidAppear: để detect IAP screens
Match class name với keywords: "Purchase", "Payment", "Subscribe"

Bước 4.2: Feature detection

Send dummy SKProductsRequest để check app có IAP không
Nếu không có products → disable hooks hoàn toàn
Nếu có → enable hooks và inject UI
Cache kết quả vào UserDefaults

Bước 4.3: Memory optimization

Lazy load AppViewController components
Release unused observers
Clear transaction cache sau khi process xong
Monitor memory với Instruments


Phase 5: Anti-Detection (Tuần 5)
Bước 5.1: Method obfuscation

Dùng dynamic selector names thay vì hardcode
Random prefix cho swizzled methods
Store original IMPs ở vị trí khó detect
Test với apps có jailbreak detection (banking apps)

Bước 5.2: IMP restoration

Trước khi app check, restore original IMP tạm thời
Sau khi check xong, hook lại
Implement timing window để detect khi nào app đang check
Test với apps có anti-tamper (games lớn)

Bước 5.3: Low-level hooking

Research hook objc_msgSend thay vì method cụ thể
Harder to detect nhưng risk hơn
Chỉ dùng cho apps có strong detection
Fallback về method hook nếu không stable


Phase 6: App-Specific Integration (Tuần 6)
Bước 6.1: YouTube integration

Dump classes với class-dump
Identify: YTIAPHandler, YTPaymentQueueObserver, YTSubscriptionController
Create YouTubeImporter.xm với specific hooks
Test premium subscription flow

Bước 6.2: Telegram integration

Identify: TGStoreKitManager, TGPremiumController, TGIAPHelper
Create TelegramImporter.xm
Hook premium status checks
Test Telegram Stars và Premium subscription

Bước 6.3: Spotify, Netflix, ... (optional)

Repeat process cho apps phổ biến khác
Tạo module riêng cho từng app
Add vào whitelist
Document classes cho mỗi app


Phase 7: Backend Sync (Tuần 7)
Bước 7.1: Export flow enhancement

Khi Export mode ON, chặn transaction hoàn toàn
Extract receipt, productID, transactionID
Gửi lên backend với endpoint /api/inventory/export
Backend lưu với status = "exported"

Bước 7.2: Import flow enhancement

Fetch inventory từ backend theo bundle ID
User chọn item muốn import
Backend mark item status = "imported"
Inject vào game qua hook (không qua Apple)

Bước 7.3: Duplicate prevention

Track transactionID đã export trong UserDefaults
Backend check transactionID trùng
Apple receipt validation để verify legitimacy
Rate limiting để prevent abuse


Phase 8: UI/UX Polish (Tuần 8)
Bước 8.1: Mode toggle UI

Segmented control: Import Mode | Export Mode
Show instructions khi switch mode
Visual indicator khi trong Export mode
Confirmation dialog trước khi export

Bước 8.2: Transaction status feedback

Loading indicator khi processing
Success/Error alerts với clear messages
Transaction history view
Sync status với backend

Bước 8.3: Settings panel

Enable/Disable cho từng app
Universal hook toggle
Clear cache button
Debug log viewer


Phase 9: Testing & Debugging (Tuần 9)
Bước 9.1: Unit testing

Test mỗi hook riêng lẻ
Mock SKPaymentQueue để test logic
Test observer priority system
Test export/import flows

Bước 9.2: Integration testing

Test với 10+ apps thực tế
Test cả free và paid apps
Test apps có/không có IAP
Document bugs và edge cases

Bước 9.3: Crash testing

Inject vào apps khi chưa init xong
Test với apps crash nhiều
Memory stress testing
Test với iOS versions khác nhau (13, 14, 15, 16)


Phase 10: Documentation & Release (Tuần 10)
Bước 10.1: Code documentation

Comment tất cả hooks
Explain tại sao cần từng hook
Document edge cases đã handle
Tạo architecture diagram

Bước 10.2: User documentation

Hướng dẫn enable/disable cho apps
Giải thích Export vs Import mode
FAQ về legal/ToS issues
Troubleshooting common problems

Bước 10.3: Release preparation

Tạo preference bundle cho settings
Package cho Cydia/Sileo
Test trên clean device
Beta test với small group


Metrics để track success:
Stability metrics:

Crash rate < 1%
Hook success rate > 95%
UI injection success rate > 98%

Performance metrics:

App launch delay < 200ms
Memory overhead < 10MB
Battery drain < 2%

Compatibility metrics:

Support 20+ popular apps
Work on iOS 13-16
No conflicts với tweaks phổ biến


Risk mitigation:
Technical risks:

Crash on init: → Phase 1 với safe injection
Observer conflicts: → Phase 2 với priority system
Detection: → Phase 5 với anti-detection
Performance: → Phase 4 với optimization
