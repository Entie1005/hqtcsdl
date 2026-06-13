-- =====================================================
-- 1_ERD / TaoBang.sql
-- Hệ thống Quản lý Nhân Khẩu
-- Mô tả: Tạo toàn bộ cấu trúc CSDL (ERD)
--   + Bảng, kiểu dữ liệu, ràng buộc
--   + Khóa chính, khóa ngoại, CHECK constraint
--   + Index tối ưu truy vấn
--   + Comment mô tả từng bảng & cột
-- Tác giả : Nhóm phát triển
-- Phiên bản: 1.0
-- =====================================================

-- =====================================================
-- BƯỚC 1: TẠO DATABASE
-- =====================================================
CREATE DATABASE IF NOT EXISTS project
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci
    COMMENT 'Hệ thống quản lý nhân khẩu';

USE project;

-- =====================================================
-- BƯỚC 2: XÓA BẢNG CŨ NẾU TỒN TẠI
--         (đảm bảo đúng thứ tự FK)
-- =====================================================
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS tienantiensu;
DROP TABLE IF EXISTS tamtru;
DROP TABLE IF EXISTS nhankhau;
DROP TABLE IF EXISTS hokhau;
DROP TABLE IF EXISTS kethon;
DROP TABLE IF EXISTS chungtu;
DROP TABLE IF EXISTS canbo;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================
-- BƯỚC 3: TẠO BẢNG
-- =====================================================

-- -----------------------------------------------------
-- BẢNG 1: hokhau
-- Lưu thông tin hộ khẩu (đơn vị quản lý dân cư).
-- Mỗi hộ khẩu có một chủ hộ duy nhất.
-- Quan hệ: 1 hokhau --- N nhankhau
-- -----------------------------------------------------
CREATE TABLE hokhau (
    MaHoKhau    CHAR(10)      NOT NULL
                              COMMENT 'Mã hộ khẩu, định dạng HKxxxxxxxx',
    TenChuHo    VARCHAR(50)   NOT NULL
                              COMMENT 'Họ và tên chủ hộ',
    CCCDChuHo   VARCHAR(20)   NOT NULL
                              COMMENT 'Số CCCD/CMND của chủ hộ',
    KhuVuc      VARCHAR(50)   NOT NULL
                              COMMENT 'Khu vực hành chính (phường/xã/thị trấn)',
    DiaChiHK    VARCHAR(100)  NOT NULL
                              COMMENT 'Địa chỉ thường trú đầy đủ của hộ khẩu',
    NgayLap     DATE          NOT NULL
                              COMMENT 'Ngày lập sổ hộ khẩu',

    -- Khóa chính
    CONSTRAINT pk_hokhau PRIMARY KEY (MaHoKhau),

    -- Ràng buộc UNIQUE
    CONSTRAINT uq_hokhau_cccd UNIQUE (CCCDChuHo)
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Bảng thông tin hộ khẩu';


-- -----------------------------------------------------
-- BẢNG 2: nhankhau
-- Lưu thông tin từng cá nhân trong hộ khẩu.
-- Quan hệ:
--   N nhankhau --- 1 hokhau       (MaHoKhau FK)
--   1 nhankhau --- N tienantiensu
--   1 nhankhau --- N tamtru
-- -----------------------------------------------------
CREATE TABLE nhankhau (
    MaNhanKhau  CHAR(10)      NOT NULL
                              COMMENT 'Mã nhân khẩu, định dạng NKxxxxxxxx',
    Ten         VARCHAR(50)   NOT NULL
                              COMMENT 'Họ và tên đầy đủ',
    NgaySinh    DATE          NOT NULL
                              COMMENT 'Ngày tháng năm sinh',
    GioiTinh    VARCHAR(10)   NOT NULL
                              COMMENT 'Giới tính: Nam / Nữ',
    QueQuan     VARCHAR(20)   NOT NULL
                              COMMENT 'Quê quán (tỉnh/thành phố gốc)',
    TonGiao     VARCHAR(20)   NOT NULL
                              COMMENT 'Tôn giáo (Không / Phật giáo / Công giáo…)',
    DanToc      VARCHAR(20)   NOT NULL
                              COMMENT 'Dân tộc (Kinh / Tày / Thái…)',
    CCCD        VARCHAR(20)   NOT NULL
                              COMMENT 'Số CCCD/CMND 12 chữ số',
    MaHoKhau    CHAR(10)      NULL
                              COMMENT 'FK → hokhau.MaHoKhau (NULL nếu chưa có hộ khẩu)',
    NgheNghiep  VARCHAR(100)  NOT NULL
                              COMMENT 'Nghề nghiệp hiện tại',

    -- Khóa chính
    CONSTRAINT pk_nhankhau PRIMARY KEY (MaNhanKhau),

    -- Ràng buộc UNIQUE
    CONSTRAINT uq_nhankhau_cccd UNIQUE (CCCD),

    -- Ràng buộc CHECK
    CONSTRAINT chk_nhankhau_gioitinh
        CHECK (GioiTinh IN ('Nam','Nữ')),
    CONSTRAINT chk_nhankhau_ngaysinh
        CHECK (NgaySinh <= CURDATE()),

    -- Khóa ngoại
    CONSTRAINT fk_nhankhau_hokhau
        FOREIGN KEY (MaHoKhau)
        REFERENCES hokhau (MaHoKhau)
        ON DELETE SET NULL
        ON UPDATE CASCADE
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Bảng thông tin nhân khẩu (cá nhân)';


-- -----------------------------------------------------
-- BẢNG 3: tienantiensu
-- Ghi nhận các tiền án, tiền sự của nhân khẩu.
-- Quan hệ: N tienantiensu --- 1 nhankhau
-- -----------------------------------------------------
CREATE TABLE tienantiensu (
    MaTienAnTienSu  CHAR(10)      NOT NULL
                                  COMMENT 'Mã hồ sơ tiền án tiền sự',
    TenTienAnTienSu VARCHAR(50)   NOT NULL
                                  COMMENT 'Tên/loại vi phạm (trộm cắp, lừa đảo…)',
    NoiXetXu        VARCHAR(100)  NOT NULL
                                  COMMENT 'Tòa án hoặc cơ quan xét xử',
    NgayThucThi     DATE          NOT NULL
                                  COMMENT 'Ngày thi hành án / quyết định',
    MaNhanKhau      CHAR(10)      NULL
                                  COMMENT 'FK → nhankhau.MaNhanKhau',

    -- Khóa chính
    CONSTRAINT pk_tienantiensu PRIMARY KEY (MaTienAnTienSu),

    -- Ràng buộc CHECK
    CONSTRAINT chk_tats_ngaythucthi
        CHECK (NgayThucThi <= CURDATE()),

    -- Khóa ngoại
    CONSTRAINT fk_tienantiensu_nhankhau
        FOREIGN KEY (MaNhanKhau)
        REFERENCES nhankhau (MaNhanKhau)
        ON DELETE SET NULL
        ON UPDATE CASCADE
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Bảng tiền án tiền sự của nhân khẩu';


-- -----------------------------------------------------
-- BẢNG 4: tamtru
-- Quản lý đăng ký tạm trú của nhân khẩu.
-- Quan hệ: N tamtru --- 1 nhankhau
-- -----------------------------------------------------
CREATE TABLE tamtru (
    MaTamTru        CHAR(10)      NOT NULL
                                  COMMENT 'Mã đăng ký tạm trú',
    TenNoiTamTru    VARCHAR(50)   NOT NULL
                                  COMMENT 'Tên nhà trọ / nơi tạm trú',
    DiaChi          VARCHAR(100)  NOT NULL
                                  COMMENT 'Địa chỉ nơi tạm trú đầy đủ',
    SoDienThoai     CHAR(10)      NOT NULL
                                  COMMENT 'Số điện thoại liên hệ nơi tạm trú',
    ThoiHan         CHAR(10)      NOT NULL
                                  COMMENT 'Thời hạn tạm trú (VD: 6 tháng, 12 tháng)',
    MaNhanKhau      CHAR(10)      NULL
                                  COMMENT 'FK → nhankhau.MaNhanKhau',

    -- Khóa chính
    CONSTRAINT pk_tamtru PRIMARY KEY (MaTamTru),

    -- Ràng buộc CHECK
    CONSTRAINT chk_tamtru_sdt
        CHECK (SoDienThoai REGEXP '^[0-9]{10}$'),

    -- Khóa ngoại
    CONSTRAINT fk_tamtru_nhankhau
        FOREIGN KEY (MaNhanKhau)
        REFERENCES nhankhau (MaNhanKhau)
        ON DELETE SET NULL
        ON UPDATE CASCADE
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Bảng đăng ký tạm trú';


-- -----------------------------------------------------
-- BẢNG 5: kethon
-- Lưu hồ sơ đăng ký kết hôn.
-- Bảng độc lập (không FK vào nhankhau vì có thể
-- đăng ký từ nơi khác chuyển đến).
-- -----------------------------------------------------
CREATE TABLE kethon (
    MaKetHon            CHAR(10)      NOT NULL
                                      COMMENT 'Mã hồ sơ kết hôn',
    TenChong            VARCHAR(50)   NOT NULL
                                      COMMENT 'Họ tên chồng',
    NgaySinhChong       DATE          NOT NULL
                                      COMMENT 'Ngày sinh của chồng',
    DanTocChong         VARCHAR(20)   NOT NULL
                                      COMMENT 'Dân tộc của chồng',
    QuocTichChong       VARCHAR(20)   NOT NULL
                                      COMMENT 'Quốc tịch của chồng',
    ThuongTamTruChong   VARCHAR(100)  NOT NULL
                                      COMMENT 'Địa chỉ thường/tạm trú của chồng',
    CCCDChong           VARCHAR(20)   NOT NULL
                                      COMMENT 'Số CCCD/CMND của chồng',
    TenVo               VARCHAR(50)   NOT NULL
                                      COMMENT 'Họ tên vợ',
    NgaySinhVo          DATE          NOT NULL
                                      COMMENT 'Ngày sinh của vợ',
    DanTocVo            VARCHAR(20)   NOT NULL
                                      COMMENT 'Dân tộc của vợ',
    QuocTichVo          VARCHAR(20)   NOT NULL
                                      COMMENT 'Quốc tịch của vợ',
    ThuongTamTruVo      VARCHAR(100)  NOT NULL
                                      COMMENT 'Địa chỉ thường/tạm trú của vợ',
    CCCDVo              VARCHAR(20)   NOT NULL
                                      COMMENT 'Số CCCD/CMND của vợ',
    KhuVucDangKy        VARCHAR(20)   NOT NULL
                                      COMMENT 'Khu vực nơi đăng ký kết hôn',
    NgayDangKy          DATE          NOT NULL
                                      COMMENT 'Ngày đăng ký kết hôn',

    -- Khóa chính
    CONSTRAINT pk_kethon PRIMARY KEY (MaKetHon),

    -- Ràng buộc UNIQUE (mỗi người chỉ có 1 hồ sơ kết hôn)
    CONSTRAINT uq_kethon_cccdchong UNIQUE (CCCDChong),
    CONSTRAINT uq_kethon_cccdvo    UNIQUE (CCCDVo),

    -- Ràng buộc CHECK
    CONSTRAINT chk_kethon_cccd_khac_nhau
        CHECK (CCCDChong <> CCCDVo),
    CONSTRAINT chk_kethon_ngaysinh_chong
        CHECK (NgaySinhChong <= CURDATE()),
    CONSTRAINT chk_kethon_ngaysinh_vo
        CHECK (NgaySinhVo <= CURDATE()),
    CONSTRAINT chk_kethon_ngaydangky
        CHECK (NgayDangKy <= CURDATE())
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Bảng hồ sơ đăng ký kết hôn';


-- -----------------------------------------------------
-- BẢNG 6: chungtu
-- Lưu chứng từ khai tử (đăng ký tử vong).
-- Bảng độc lập (người mất có thể không còn
-- trong nhankhau nếu đã xuất hộ khẩu).
-- -----------------------------------------------------
CREATE TABLE chungtu (
    MaChungTu           CHAR(10)      NOT NULL
                                      COMMENT 'Mã chứng từ khai tử',
    TenNguoiKhai        VARCHAR(50)   NOT NULL
                                      COMMENT 'Họ tên người đến khai tử',
    ThuongTamTru        VARCHAR(100)  NOT NULL
                                      COMMENT 'Địa chỉ thường/tạm trú của người khai',
    QuanHeVoiNguoiMat   VARCHAR(20)   NOT NULL
                                      COMMENT 'Quan hệ với người mất (con/vợ/chồng…)',
    TenNguoiMat         VARCHAR(50)   NOT NULL
                                      COMMENT 'Họ tên người mất',
    NgaySinh            DATE          NOT NULL
                                      COMMENT 'Ngày sinh của người mất',
    DanToc              VARCHAR(20)   NOT NULL
                                      COMMENT 'Dân tộc của người mất',
    QuocTich            VARCHAR(20)   NOT NULL
                                      COMMENT 'Quốc tịch của người mất',
    CCCD                VARCHAR(20)   NOT NULL
                                      COMMENT 'Số CCCD/CMND của người mất',
    NgayMat             DATE          NOT NULL
                                      COMMENT 'Ngày mất',
    GioMat              CHAR(5)       NOT NULL
                                      COMMENT 'Giờ mất, định dạng HH:MM',
    KhuVucDangKy        VARCHAR(20)   NOT NULL
                                      COMMENT 'Khu vực đăng ký khai tử',
    NgayDangKy          DATE          NOT NULL
                                      COMMENT 'Ngày làm thủ tục khai tử',

    -- Khóa chính
    CONSTRAINT pk_chungtu PRIMARY KEY (MaChungTu),

    -- Ràng buộc UNIQUE (mỗi người chỉ có 1 chứng từ khai tử)
    CONSTRAINT uq_chungtu_cccd UNIQUE (CCCD),

    -- Ràng buộc CHECK
    CONSTRAINT chk_chungtu_ngaymat
        CHECK (NgayMat <= CURDATE()),
    CONSTRAINT chk_chungtu_ngaydangky
        CHECK (NgayDangKy >= NgayMat),
    CONSTRAINT chk_chungtu_ngaysinh
        CHECK (NgaySinh < NgayMat),
    CONSTRAINT chk_chungtu_giomatformat
        CHECK (GioMat REGEXP '^([01][0-9]|2[0-3]):[0-5][0-9]$')
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Bảng chứng từ khai tử';


-- -----------------------------------------------------
-- BẢNG 7: canbo
-- Tài khoản đăng nhập của cán bộ quản lý.
-- -----------------------------------------------------
CREATE TABLE canbo (
    TaiKhoan    CHAR(20)      NOT NULL
                              COMMENT 'Tên tài khoản đăng nhập',
    MatKhau     CHAR(20)      NOT NULL
                              COMMENT 'Mật khẩu (nên mã hoá ở tầng ứng dụng)',

    -- Khóa chính
    CONSTRAINT pk_canbo PRIMARY KEY (TaiKhoan)
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Bảng tài khoản cán bộ quản lý';


-- =====================================================
-- BƯỚC 4: TẠO INDEX TỐI ƯU TRUY VẤN
-- =====================================================

-- ── hokhau ───────────────────────────────────────────
-- Tìm kiếm theo khu vực (thống kê dân số)
CREATE INDEX idx_hokhau_khuvuc
    ON hokhau (KhuVuc);

-- Tìm kiếm chủ hộ theo tên
CREATE INDEX idx_hokhau_tenchuho
    ON hokhau (TenChuHo);

-- ── nhankhau ─────────────────────────────────────────
-- JOIN với hokhau
CREATE INDEX idx_nhankhau_mahokhau
    ON nhankhau (MaHoKhau);

-- Lọc theo độ tuổi / thống kê dân số
CREATE INDEX idx_nhankhau_ngaysinh
    ON nhankhau (NgaySinh);

-- Tra cứu nhanh theo CCCD
CREATE INDEX idx_nhankhau_cccd
    ON nhankhau (CCCD);

-- Tìm kiếm theo tên
CREATE INDEX idx_nhankhau_ten
    ON nhankhau (Ten);

-- Thống kê theo giới tính
CREATE INDEX idx_nhankhau_gioitinh
    ON nhankhau (GioiTinh);

-- ── tienantiensu ─────────────────────────────────────
-- JOIN với nhankhau
CREATE INDEX idx_tienantiensu_manhankhau
    ON tienantiensu (MaNhanKhau);

-- Lọc theo ngày thực thi
CREATE INDEX idx_tienantiensu_ngaythucthi
    ON tienantiensu (NgayThucThi);

-- ── tamtru ───────────────────────────────────────────
-- JOIN với nhankhau
CREATE INDEX idx_tamtru_manhankhau
    ON tamtru (MaNhanKhau);

-- ── kethon ───────────────────────────────────────────
-- Tra cứu theo CCCD chồng / vợ
CREATE INDEX idx_kethon_cccdchong
    ON kethon (CCCDChong);

CREATE INDEX idx_kethon_cccdvo
    ON kethon (CCCDVo);

-- Thống kê theo ngày / năm đăng ký
CREATE INDEX idx_kethon_ngaydangky
    ON kethon (NgayDangKy);

-- Thống kê theo khu vực đăng ký
CREATE INDEX idx_kethon_khuvucdangky
    ON kethon (KhuVucDangKy);

-- ── chungtu ──────────────────────────────────────────
-- Tra cứu theo CCCD người mất
CREATE INDEX idx_chungtu_cccd
    ON chungtu (CCCD);

-- Thống kê tử vong theo ngày / năm
CREATE INDEX idx_chungtu_ngaymat
    ON chungtu (NgayMat);

-- Thống kê theo khu vực
CREATE INDEX idx_chungtu_khuvucdangky
    ON chungtu (KhuVucDangKy);

-- ── canbo ────────────────────────────────────────────
-- Đăng nhập tìm theo tài khoản (đã là PK, không cần thêm)
-- Index phụ cho mật khẩu (tìm kiếm kết hợp)
CREATE INDEX idx_canbo_matkhau
    ON canbo (MatKhau);


-- =====================================================
-- BƯỚC 5: KIỂM TRA CẤU TRÚC SAU KHI TẠO
-- =====================================================
/*
-- Xem toàn bộ bảng trong database
SHOW TABLES;

-- Xem cấu trúc chi tiết từng bảng
DESCRIBE hokhau;
DESCRIBE nhankhau;
DESCRIBE tienantiensu;
DESCRIBE tamtru;
DESCRIBE kethon;
DESCRIBE chungtu;
DESCRIBE canbo;

-- Xem toàn bộ index
SELECT
    TABLE_NAME,
    INDEX_NAME,
    COLUMN_NAME,
    NON_UNIQUE,
    INDEX_TYPE
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'project'
ORDER BY TABLE_NAME, INDEX_NAME;

-- Xem toàn bộ khóa ngoại
SELECT
    TABLE_NAME,
    CONSTRAINT_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'project'
  AND REFERENCED_TABLE_NAME IS NOT NULL;

-- Xem toàn bộ ràng buộc CHECK
SELECT
    TABLE_NAME,
    CONSTRAINT_NAME,
    CHECK_CLAUSE
FROM information_schema.CHECK_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'project';
*/


-- =====================================================
-- TỔNG KẾT ERD
-- =====================================================
/*
┌─────────────────────────────────────────────────────┐
│              SƠ ĐỒ QUAN HỆ (ERD)                   │
├─────────────────────────────────────────────────────┤
│                                                     │
│   hokhau  ─────────< nhankhau                       │
│   (PK: MaHoKhau)      (FK: MaHoKhau)               │
│                            │                        │
│                            ├──────< tienantiensu    │
│                            │       (FK: MaNhanKhau) │
│                            │                        │
│                            └──────< tamtru          │
│                                    (FK: MaNhanKhau) │
│                                                     │
│   kethon  (độc lập - tra cứu qua CCCDChong/CCCDVo) │
│                                                     │
│   chungtu (độc lập - tra cứu qua CCCD người mất)   │
│                                                     │
│   canbo   (độc lập - xác thực đăng nhập)           │
│                                                     │
├─────────────────────────────────────────────────────┤
│  Ký hiệu: ─────  một     <───  nhiều               │
│           (1)          (N)                          │
└─────────────────────────────────────────────────────┘

Quan hệ:
  hokhau       1 ── N  nhankhau       (1 hộ có nhiều nhân khẩu)
  nhankhau     1 ── N  tienantiensu   (1 người có thể có nhiều tiền án)
  nhankhau     1 ── N  tamtru         (1 người có thể có nhiều lần tạm trú)
  kethon       độc lập (liên kết logic qua CCCD)
  chungtu      độc lập (liên kết logic qua CCCD)
  canbo        độc lập (hệ thống xác thực)

Bảng          | Cột | PK | FK | UQ | INDEX
──────────────|─────|────|────|────|──────
hokhau        |   6 |  1 |  0 |  1 |  2
nhankhau      |  10 |  1 |  1 |  1 |  5
tienantiensu  |   5 |  1 |  1 |  0 |  2
tamtru        |   6 |  1 |  1 |  0 |  1
kethon        |  15 |  1 |  0 |  2 |  4
chungtu       |  13 |  1 |  0 |  1 |  3
canbo         |   2 |  1 |  0 |  0 |  1
*/
