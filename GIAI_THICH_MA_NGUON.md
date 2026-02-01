# Giải thích mã nguồn (Import tweak)

## 1. Tổng quan kiến trúc
Mã nguồn này là một tweak iOS (sử dụng Theos/Logos) để chèn một giao diện “import” vào các game mục tiêu và can thiệp vào luồng thanh toán IAP. Điểm vào chính (`Tweak.xm`) khởi tạo các bộ hook cho từng game. Mỗi bộ hook sẽ:

- Chặn hoặc ghi log các callback IAP (để “paralyze” luồng xử lý của game gốc).
- Chèn `AppViewController` làm root view controller để hiển thị UI nhập kho (import UI).

Các lớp UI chính gồm:

- `AppViewController`: dựng giao diện tổng thể và điều phối thanh toán.
- `AppTopViewController`: thanh đăng nhập.
- `ProductListViewController`: danh sách sản phẩm/inventory.
- `ProductViewController`: từng dòng sản phẩm có thể tap để mua.
- `VBStoreKitManager`: observer của StoreKit, gửi receipt lên backend và cập nhật UI.

Các phần này phối hợp với `AuthManager` để kiểm tra đăng nhập, và sử dụng các sự kiện `NSNotification` để đồng bộ luồng dữ liệu giữa các màn hình. 【F:Tweak.xm†L1-L17】【F:src/AppViewController.m†L1-L116】【F:src/AppTopViewController.m†L1-L192】【F:src/ProductListViewController.m†L1-L240】【F:src/ProductViewController.m†L1-L86】【F:src/VBStoreKitManager.m†L1-L115】

## 2. Điểm vào và cơ chế hook theo game
### 2.1 `Tweak.xm`
`%ctor` là điểm khởi tạo của tweak. Tại đây lần lượt gọi các hàm `Init*Importer()` để kích hoạt nhóm hook cho từng game: Lineage2M, Arknights, LineageM, Snail. 【F:Tweak.xm†L1-L17】

### 2.2 Hook cho từng game
- **Lineage2M**: chặn các callback StoreKit trong `AppleInAppPurchaseManager`, `FStoreKitHelperV2`, `FStoreKitHelper`. Đồng thời hook `IOSAppDelegate` để chèn `AppViewController` khi app active. 【F:src/Lineage2MImporter.xm†L1-L48】
- **Arknights**: hook `StoreKitManager -init` để chèn `AppViewController` ngay khi đối tượng quản lý StoreKit được tạo. 【F:src/ArknightsImporter.xm†L1-L29】
- **LineageM**: hook `FBSDKPaymentObserver` để ghi log callback payment, và hook `AppController` để hiển thị `AppViewController` khi app active. 【F:src/LineageMLiveImporter.xm†L1-L33】
- **Snail**: hook nhiều lớp liên quan payment (`APMAnalytics`, `FBSDKPaymentObserver`, `PayModule`, `UADSTransactionObserver`) để chặn callback IAP. Không tự chèn UI vì dùng chung hook `AppController` với LineageM. 【F:src/SnailImporter.xm†L1-L33】

## 3. Luồng UI và xử lý nghiệp vụ
### 3.1 `AppViewController` — giao diện tổng và điều phối
- Khởi tạo view chính, bật tương tác, gắn tap gesture để ẩn bàn phím. 【F:src/AppViewController.m†L17-L52】【F:src/AppViewController.m†L109-L112】
- Tạo và nhúng `AppTopViewController` (thanh đăng nhập) và `ProductListViewController` (danh sách sản phẩm). 【F:src/AppViewController.m†L54-L62】
- Lắng nghe notification `notifyInappPayment` để bắt sự kiện mua khi người dùng tap sản phẩm; nếu chưa đăng nhập thì hiển thị cảnh báo. 【F:src/AppViewController.m†L64-L101】
- Đăng ký `VBStoreKitManager` làm `SKPaymentTransactionObserver` để nhận trạng thái giao dịch IAP. 【F:src/AppViewController.m†L69-L74】
- `renderImportApp:` đặt view controller này làm `rootViewController` của app để hiển thị giao diện import đè lên app gốc. 【F:src/AppViewController.m†L81-L89】

### 3.2 `AppTopViewController` — đăng nhập
- Tạo hai `UITextField` cho username/password và nút đăng nhập. 【F:src/AppTopViewController.m†L28-L86】
- Khi người dùng nhập, dữ liệu được lưu vào `AuthModel`. 【F:src/AppTopViewController.m†L100-L107】【F:src/AuthModel.h†L1-L9】
- Khi nhấn đăng nhập, kiểm tra rỗng; nếu OK thì gọi `HttpUtil login`. Nếu login thành công (`statusCode == 200`), lưu JWT vào `AuthManager`. 【F:src/AppTopViewController.m†L109-L179】【F:src/Auth/AuthManager.m†L1-L21】

### 3.3 `ProductListViewController` — tải và hiển thị inventory
- Dựng `UIScrollView`, `contentView` và `UIStackView` để hiển thị danh sách sản phẩm theo cột. 【F:src/ProductListViewController.m†L14-L93】【F:src/ProductListViewController.m†L139-L200】
- Lắng nghe:
  - `notifyRefreshProducts`: gọi API lấy inventory theo bundle ID.
  - `notifyProductsUpdate`: render danh sách sản phẩm mới. 【F:src/ProductListViewController.m†L36-L75】
- `fetchInventoryAndReact:` gọi `HttpUtil fetchInventory`, parse JSON, chuyển thành mảng `Product`, lưu vào `self.products`, rồi bắn `notifyProductsUpdate`. 【F:src/ProductListViewController.m†L88-L138】

### 3.4 `ProductViewController` — từng dòng sản phẩm và hành vi mua
- Tạo 1 dòng UI (row) gồm tên, giá, số lượng. 【F:src/ProductViewController.m†L51-L79】
- Bắt tap: gửi notification `notifyInappPayment` kèm `prodID` để `AppViewController` kích hoạt thanh toán IAP. 【F:src/ProductViewController.m†L31-L49】

## 4. Luồng thanh toán IAP và đồng bộ inventory
### 4.1 Kích hoạt mua
- Khi user tap sản phẩm, `ProductViewController` gửi `notifyInappPayment`. 【F:src/ProductViewController.m†L31-L49】
- `AppViewController` nhận notification, kiểm tra đăng nhập (`AuthManager`), sau đó tạo `SKMutablePayment` với `productIdentifier` và thêm vào `SKPaymentQueue`. 【F:src/AppViewController.m†L91-L104】【F:src/Auth/AuthManager.m†L1-L21】

### 4.2 Xử lý transaction
`VBStoreKitManager` là observer của `SKPaymentQueue`. Khi `transactionState == Purchased`:

- Lấy receipt từ `appStoreReceiptURL`, encode base64.
- Gọi `HttpUtil addItemToInventory` gửi `productID`, `transactionIdentifier`, receipt, và thời điểm giao dịch.
- Nếu backend trả 200: gọi `finishTransaction`, hiển thị Alert thành công, và phát `notifyRefreshProducts` để cập nhật danh sách.
- Nếu lỗi: hiển thị Alert. 【F:src/VBStoreKitManager.m†L17-L104】

## 5. Cơ chế notification và đồng bộ giữa các màn hình
Hệ thống dùng `NSNotificationCenter` cho các luồng:

- `notifyInappPayment`: phát từ `ProductViewController` khi user tap; nhận bởi `AppViewController` để tạo thanh toán. 【F:src/ProductViewController.m†L31-L49】【F:src/AppViewController.m†L64-L104】
- `notifyRefreshProducts`: phát khi cần refresh inventory (sau mua thành công hoặc khi khởi tạo). `ProductListViewController` lắng nghe để gọi API. 【F:src/ProductListViewController.m†L36-L62】【F:src/VBStoreKitManager.m†L88-L98】
- `notifyProductsUpdate`: phát sau khi API trả về inventory; `ProductListViewController` dùng để render UI. 【F:src/ProductListViewController.m†L64-L138】

## 6. Tóm tắt chức năng chính
- **Chèn giao diện import** vào các game được hook để hiển thị đăng nhập + danh sách sản phẩm. 【F:Tweak.xm†L1-L17】【F:src/AppViewController.m†L81-L89】
- **Quản lý đăng nhập** qua `AppTopViewController` và `AuthManager` (JWT). 【F:src/AppTopViewController.m†L109-L179】【F:src/Auth/AuthManager.m†L1-L21】
- **Tải inventory** theo bundle ID và render danh sách sản phẩm. 【F:src/ProductListViewController.m†L70-L138】
- **Kích hoạt IAP** khi người dùng chọn sản phẩm, xử lý receipt, gửi lên backend và refresh inventory. 【F:src/ProductViewController.m†L31-L79】【F:src/AppViewController.m†L91-L104】【F:src/VBStoreKitManager.m†L17-L104】

## 7. Gợi ý giảm phụ thuộc vào cập nhật giao diện/phiên bản game
Nếu mục tiêu là **không phụ thuộc vào UI/game update** và chỉ cần game còn tồn tại một trong các class hook như `AppleInAppPurchaseManager`, `StoreKitManager`, hoặc `FBSDKPaymentObserver`, thì hướng phù hợp nhất là **runtime class detection** (phát hiện class tại runtime) rồi mới kích hoạt nhóm hook tương ứng.

### 7.1 Hướng khuyến nghị: Runtime class detection
- **Ý tưởng:** chỉ `%init` nhóm hook khi `NSClassFromString(@"TênClass")` trả về khác `nil`.
- **Ưu điểm:** tránh crash khi class không tồn tại do game update; không phụ thuộc vào thay đổi UI vì hook theo class backend xử lý IAP.
- **Điều kiện để hoạt động:** game vẫn dùng các class mục tiêu nêu trên (ví dụ `AppleInAppPurchaseManager`, `StoreKitManager`, `FBSDKPaymentObserver`).

> Lưu ý: hiện tại `%ctor` đang init tất cả nhóm hook một lúc, chưa có kiểm tra class tồn tại hay không.【F:Tweak.xm†L1-L17】

## 8. Export/Import mode cho kho giao dịch IAP
Mã nguồn đã bổ sung cơ chế **Export/Import Mode** để tách việc lưu giao dịch IAP lên backend khỏi việc “consume” trong game:

- **Export Mode:** khi nhận `SKPaymentTransactionStatePurchased`, giao dịch được gửi lên backend và kết thúc transaction để lưu vào kho; hiển thị thông báo export thành công. 【F:src/VBStoreKitManager.m†L17-L66】【F:src/ExportManager.m†L21-L74】
- **Import Mode:** khi nhận giao dịch, hệ thống kiểm tra kho xem item đã export chưa; nếu có thì đánh dấu imported và kết thúc transaction; nếu không thì dùng luồng cũ (gửi receipt để thêm kho). 【F:src/VBStoreKitManager.m†L68-L184】【F:src/ExportManager.m†L76-L117】
- **UI Toggle:** `AppViewController` thêm `UISegmentedControl` để bật/tắt Export Mode trong runtime. 【F:src/AppViewController.m†L60-L116】
