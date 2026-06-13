-- =====================================================
-- 6. TRIGGERS
-- Hệ thống quản lý nhân khẩu
-- =====================================================

USE project;

-- =====================================================
-- BẢNG PHỤ TRỢ - LƯU LỊCH SỬ & LOG
-- Tạo trước khi định nghĩa các trigger.
-- =====================================================

-- Bảng ghi log thay đổi nhân khẩu
CREATE TABLE IF NOT EXISTS log_nhankhau (
    LogID        INT AUTO_INCREMENT PRIMARY KEY,
    MaNhanKhau   CHAR(10),
    HanhDong     VARCHAR(10),          -- INSERT / UPDATE / DELETE
    TruongThayDoi VARCHAR(50),
    GiaTriCu     VARCHAR(200),
    GiaTriMoi    VARCHAR(200),
    ThoiGian     DATETIME DEFAULT CURRENT_TIMESTAMP,
    GhiChu       VARCHAR(255)
);

-- Bảng thống kê số nhân khẩu theo hộ khẩu (tự động cập nhật qua trigger)
CREATE TABLE IF NOT EXISTS thongke_hokhau (
    MaHoKhau     CHAR(10) PRIMARY KEY,
    SoNhanKhau   INT DEFAULT 0,
    CapNhatLuc   DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Khởi tạo dữ liệu thống kê từ bảng hiện có
INSERT INTO thongke_hokhau (MaHoKhau, SoNhanKhau)
SELECT MaHoKhau, COUNT(*) FROM nhankhau GROUP BY MaHoKhau
ON DUPLICATE KEY UPDATE SoNhanKhau = VALUES(SoNhanKhau);

-- Bảng lịch sử chuyển hộ khẩu
CREATE TABLE IF NOT EXISTS lichsu_chuyen_hokhau (
    LichSuID     INT AUTO_INCREMENT PRIMARY KEY,
    MaNhanKhau   CHAR(10),
    HoKhauCu    CHAR(10),
    HoKhauMoi   CHAR(10),
    NgayChuyen  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Bảng cảnh báo tiền án tiền sự (khi INSERT mới)
CREATE TABLE IF NOT EXISTS canhbao_tienantiensu (
    CanhBaoID    INT AUTO_INCREMENT PRIMARY KEY,
    MaTienAnTienSu CHAR(10),
    MaNhanKhau   CHAR(10),
    TenNhanKhau  VARCHAR(50),
    MaHoKhau     CHAR(10),
    LoaiVuAn     VARCHAR(50),
    ThoiGian     DATETIME DEFAULT CURRENT_TIMESTAMP,
    TrangThai    VARCHAR(20) DEFAULT 'Chưa xử lý'
);

-- Bảng log đăng nhập / thao tác cán bộ
CREATE TABLE IF NOT EXISTS log_canbo (
    LogID        INT AUTO_INCREMENT PRIMARY KEY,
    TaiKhoan     CHAR(20),
    HanhDong     VARCHAR(20),          -- INSERT / UPDATE / DELETE
    ThoiGian     DATETIME DEFAULT CURRENT_TIMESTAMP,
    GhiChu       VARCHAR(255)
);

-- =====================================================
-- 6.1 TRIGGER: tg_nhankhau_after_insert
-- Sau khi thêm nhân khẩu mới:
--   • Cập nhật số nhân khẩu trong bảng thống kê
--   • Ghi log INSERT
-- =====================================================

DROP TRIGGER IF EXISTS tg_nhankhau_after_insert;

DELIMITER $$

CREATE TRIGGER tg_nhankhau_after_insert
AFTER INSERT ON nhankhau
FOR EACH ROW
BEGIN
    -- Cập nhật (hoặc tạo mới) bản ghi thống kê cho hộ khẩu
    INSERT INTO thongke_hokhau (MaHoKhau, SoNhanKhau)
    VALUES (NEW.MaHoKhau, 1)
    ON DUPLICATE KEY UPDATE SoNhanKhau = SoNhanKhau + 1;

    -- Ghi log
    INSERT INTO log_nhankhau (MaNhanKhau, HanhDong, TruongThayDoi, GiaTriCu, GiaTriMoi, GhiChu)
    VALUES (
        NEW.MaNhanKhau,
        'INSERT',
        'Toàn bộ bản ghi',
        NULL,
        CONCAT('Ten=', NEW.Ten, ', MaHoKhau=', IFNULL(NEW.MaHoKhau,'NULL'),
               ', NgheNghiep=', NEW.NgheNghiep),
        'Thêm nhân khẩu mới'
    );
END$$

DELIMITER ;

-- =====================================================
-- 6.2 TRIGGER: tg_nhankhau_after_update
-- Sau khi cập nhật nhân khẩu:
--   • Nếu đổi hộ khẩu → cập nhật thống kê 2 bên
--                      → ghi lịch sử chuyển hộ khẩu
--   • Ghi log từng trường thay đổi (NgheNghiep, MaHoKhau)
-- =====================================================

DROP TRIGGER IF EXISTS tg_nhankhau_after_update;

DELIMITER $$

CREATE TRIGGER tg_nhankhau_after_update
AFTER UPDATE ON nhankhau
FOR EACH ROW
BEGIN
    -- Xử lý khi chuyển hộ khẩu
    IF OLD.MaHoKhau <> NEW.MaHoKhau OR
       (OLD.MaHoKhau IS NULL AND NEW.MaHoKhau IS NOT NULL) OR
       (OLD.MaHoKhau IS NOT NULL AND NEW.MaHoKhau IS NULL) THEN

        -- Giảm đếm ở hộ khẩu cũ
        UPDATE thongke_hokhau
        SET SoNhanKhau = GREATEST(SoNhanKhau - 1, 0)
        WHERE MaHoKhau = OLD.MaHoKhau;

        -- Tăng đếm ở hộ khẩu mới
        INSERT INTO thongke_hokhau (MaHoKhau, SoNhanKhau)
        VALUES (NEW.MaHoKhau, 1)
        ON DUPLICATE KEY UPDATE SoNhanKhau = SoNhanKhau + 1;

        -- Ghi lịch sử chuyển hộ khẩu
        INSERT INTO lichsu_chuyen_hokhau (MaNhanKhau, HoKhauCu, HoKhauMoi)
        VALUES (NEW.MaNhanKhau, OLD.MaHoKhau, NEW.MaHoKhau);

        -- Ghi log chuyển hộ khẩu
        INSERT INTO log_nhankhau (MaNhanKhau, HanhDong, TruongThayDoi, GiaTriCu, GiaTriMoi, GhiChu)
        VALUES (
            NEW.MaNhanKhau, 'UPDATE', 'MaHoKhau',
            OLD.MaHoKhau, NEW.MaHoKhau,
            'Chuyển hộ khẩu'
        );
    END IF;

    -- Ghi log khi đổi nghề nghiệp
    IF OLD.NgheNghiep <> NEW.NgheNghiep THEN
        INSERT INTO log_nhankhau (MaNhanKhau, HanhDong, TruongThayDoi, GiaTriCu, GiaTriMoi, GhiChu)
        VALUES (
            NEW.MaNhanKhau, 'UPDATE', 'NgheNghiep',
            OLD.NgheNghiep, NEW.NgheNghiep,
            'Cập nhật nghề nghiệp'
        );
    END IF;

    -- Ghi log khi đổi CCCD
    IF OLD.CCCD <> NEW.CCCD THEN
        INSERT INTO log_nhankhau (MaNhanKhau, HanhDong, TruongThayDoi, GiaTriCu, GiaTriMoi, GhiChu)
        VALUES (
            NEW.MaNhanKhau, 'UPDATE', 'CCCD',
            OLD.CCCD, NEW.CCCD,
            'Cập nhật CCCD'
        );
    END IF;
END$$

DELIMITER ;

-- =====================================================
-- 6.3 TRIGGER: tg_nhankhau_after_delete
-- Sau khi xóa nhân khẩu:
--   • Giảm số nhân khẩu trong thống kê
--   • Xóa các bản ghi liên quan (tạm trú, tiền án)
--   • Ghi log DELETE
-- =====================================================

DROP TRIGGER IF EXISTS tg_nhankhau_after_delete;

DELIMITER $$

CREATE TRIGGER tg_nhankhau_after_delete
AFTER DELETE ON nhankhau
FOR EACH ROW
BEGIN
    -- Giảm đếm thống kê hộ khẩu
    UPDATE thongke_hokhau
    SET SoNhanKhau = GREATEST(SoNhanKhau - 1, 0)
    WHERE MaHoKhau = OLD.MaHoKhau;

    -- Ghi log xóa
    INSERT INTO log_nhankhau (MaNhanKhau, HanhDong, TruongThayDoi, GiaTriCu, GiaTriMoi, GhiChu)
    VALUES (
        OLD.MaNhanKhau,
        'DELETE',
        'Toàn bộ bản ghi',
        CONCAT('Ten=', OLD.Ten, ', MaHoKhau=', IFNULL(OLD.MaHoKhau,'NULL')),
        NULL,
        'Xóa nhân khẩu'
    );
END$$

DELIMITER ;

-- =====================================================
-- 6.4 TRIGGER: tg_tienantiensu_after_insert
-- Sau khi ghi nhận tiền án tiền sự mới:
--   • Tạo cảnh báo để cán bộ theo dõi
-- =====================================================

DROP TRIGGER IF EXISTS tg_tienantiensu_after_insert;

DELIMITER $$

CREATE TRIGGER tg_tienantiensu_after_insert
AFTER INSERT ON tienantiensu
FOR EACH ROW
BEGIN
    DECLARE v_Ten       VARCHAR(50);
    DECLARE v_MaHoKhau  CHAR(10);

    -- Lấy thông tin nhân khẩu liên quan
    SELECT Ten, MaHoKhau
    INTO v_Ten, v_MaHoKhau
    FROM nhankhau
    WHERE MaNhanKhau = NEW.MaNhanKhau;

    -- Tạo bản ghi cảnh báo
    INSERT INTO canhbao_tienantiensu
        (MaTienAnTienSu, MaNhanKhau, TenNhanKhau, MaHoKhau, LoaiVuAn)
    VALUES
        (NEW.MaTienAnTienSu, NEW.MaNhanKhau, v_Ten, v_MaHoKhau, NEW.TenTienAnTienSu);
END$$

DELIMITER ;

-- =====================================================
-- 6.5 TRIGGER: tg_tamtru_before_insert
-- Trước khi thêm tạm trú:
--   • Kiểm tra nhân khẩu phải tồn tại
--   • Kiểm tra thời hạn hợp lệ (3/6/12/24 tháng)
-- =====================================================

DROP TRIGGER IF EXISTS tg_tamtru_before_insert;

DELIMITER $$

CREATE TRIGGER tg_tamtru_before_insert
BEFORE INSERT ON tamtru
FOR EACH ROW
BEGIN
    -- Kiểm tra nhân khẩu tồn tại
    IF NOT EXISTS (SELECT 1 FROM nhankhau WHERE MaNhanKhau = NEW.MaNhanKhau) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không thể thêm tạm trú: Mã nhân khẩu không tồn tại.';
    END IF;

    -- Kiểm tra thời hạn hợp lệ
    IF NEW.ThoiHan NOT IN ('3 tháng', '6 tháng', '12 tháng', '24 tháng') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Thời hạn tạm trú không hợp lệ. Chỉ chấp nhận: 3/6/12/24 tháng.';
    END IF;
END$$

DELIMITER ;

-- =====================================================
-- 6.6 TRIGGER: tg_tamtru_after_delete
-- Sau khi xóa tạm trú:
--   • Ghi log để theo dõi ai rời khỏi địa điểm
-- =====================================================

DROP TRIGGER IF EXISTS tg_tamtru_after_delete;

DELIMITER $$

CREATE TRIGGER tg_tamtru_after_delete
AFTER DELETE ON tamtru
FOR EACH ROW
BEGIN
    INSERT INTO log_nhankhau (MaNhanKhau, HanhDong, TruongThayDoi, GiaTriCu, GiaTriMoi, GhiChu)
    VALUES (
        OLD.MaNhanKhau,
        'DELETE',
        'tamtru',
        CONCAT('NoiTamTru=', OLD.TenNoiTamTru, ', DiaChi=', OLD.DiaChi),
        NULL,
        CONCAT('Hủy tạm trú, thời hạn: ', OLD.ThoiHan)
    );
END$$

DELIMITER ;

-- =====================================================
-- 6.7 TRIGGER: tg_hokhau_before_delete
-- Trước khi xóa hộ khẩu:
--   • Ngăn xóa nếu còn nhân khẩu đang thuộc hộ khẩu đó
-- =====================================================

DROP TRIGGER IF EXISTS tg_hokhau_before_delete;

DELIMITER $$

CREATE TRIGGER tg_hokhau_before_delete
BEFORE DELETE ON hokhau
FOR EACH ROW
BEGIN
    DECLARE v_SoNhanKhau INT;

    SELECT COUNT(*) INTO v_SoNhanKhau
    FROM nhankhau
    WHERE MaHoKhau = OLD.MaHoKhau;

    IF v_SoNhanKhau > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không thể xóa hộ khẩu: vẫn còn nhân khẩu thuộc hộ khẩu này.';
    END IF;
END$$

DELIMITER ;

-- =====================================================
-- 6.8 TRIGGER: tg_hokhau_after_update
-- Sau khi cập nhật địa chỉ hộ khẩu:
--   • Ghi log thay đổi để phục vụ kiểm tra
-- =====================================================

DROP TRIGGER IF EXISTS tg_hokhau_after_update;

DELIMITER $$

CREATE TRIGGER tg_hokhau_after_update
AFTER UPDATE ON hokhau
FOR EACH ROW
BEGIN
    IF OLD.DiaChiHK <> NEW.DiaChiHK THEN
        INSERT INTO log_nhankhau (MaNhanKhau, HanhDong, TruongThayDoi, GiaTriCu, GiaTriMoi, GhiChu)
        VALUES (
            NULL,
            'UPDATE',
            CONCAT('hokhau.DiaChiHK [', OLD.MaHoKhau, ']'),
            OLD.DiaChiHK,
            NEW.DiaChiHK,
            CONCAT('Cập nhật địa chỉ hộ khẩu: ', OLD.MaHoKhau)
        );
    END IF;

    IF OLD.KhuVuc <> NEW.KhuVuc THEN
        INSERT INTO log_nhankhau (MaNhanKhau, HanhDong, TruongThayDoi, GiaTriCu, GiaTriMoi, GhiChu)
        VALUES (
            NULL,
            'UPDATE',
            CONCAT('hokhau.KhuVuc [', OLD.MaHoKhau, ']'),
            OLD.KhuVuc,
            NEW.KhuVuc,
            CONCAT('Cập nhật khu vực hộ khẩu: ', OLD.MaHoKhau)
        );
    END IF;
END$$

DELIMITER ;

-- =====================================================
-- 6.9 TRIGGER: tg_canbo_after_insert / after_delete
-- Ghi log khi thêm hoặc xóa tài khoản cán bộ.
-- =====================================================

DROP TRIGGER IF EXISTS tg_canbo_after_insert;

DELIMITER $$

CREATE TRIGGER tg_canbo_after_insert
AFTER INSERT ON canbo
FOR EACH ROW
BEGIN
    INSERT INTO log_canbo (TaiKhoan, HanhDong, GhiChu)
    VALUES (NEW.TaiKhoan, 'INSERT', 'Tạo tài khoản cán bộ mới');
END$$

DELIMITER ;

DROP TRIGGER IF EXISTS tg_canbo_after_delete;

DELIMITER $$

CREATE TRIGGER tg_canbo_after_delete
AFTER DELETE ON canbo
FOR EACH ROW
BEGIN
    INSERT INTO log_canbo (TaiKhoan, HanhDong, GhiChu)
    VALUES (OLD.TaiKhoan, 'DELETE', 'Xóa tài khoản cán bộ');
END$$

DELIMITER ;

-- =====================================================
-- 6.10 TRIGGER: tg_canbo_before_update (bảo mật mật khẩu)
-- Trước khi đổi mật khẩu cán bộ:
--   • Yêu cầu mật khẩu mới phải có ít nhất 6 ký tự
--   • Ghi log thay đổi mật khẩu
-- =====================================================

DROP TRIGGER IF EXISTS tg_canbo_before_update;

DELIMITER $$

CREATE TRIGGER tg_canbo_before_update
BEFORE UPDATE ON canbo
FOR EACH ROW
BEGIN
    IF OLD.MatKhau <> NEW.MatKhau THEN
        -- Kiểm tra độ dài tối thiểu
        IF CHAR_LENGTH(NEW.MatKhau) < 6 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Mật khẩu mới phải có ít nhất 6 ký tự.';
        END IF;
    END IF;
END$$

DELIMITER ;

-- =====================================================
-- 6.11 TRIGGER: tg_kethon_before_insert
-- Trước khi đăng ký kết hôn:
--   • Kiểm tra ngày đăng ký không vượt quá ngày hiện tại
--   • Kiểm tra người chồng và vợ không cùng CCCD
-- =====================================================

DROP TRIGGER IF EXISTS tg_kethon_before_insert;

DELIMITER $$

CREATE TRIGGER tg_kethon_before_insert
BEFORE INSERT ON kethon
FOR EACH ROW
BEGIN
    -- Ngày đăng ký không được là ngày tương lai
    IF NEW.NgayDangKy > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ngày đăng ký kết hôn không được là ngày trong tương lai.';
    END IF;

    -- CCCD vợ và chồng phải khác nhau
    IF NEW.CCCDChong = NEW.CCCDVo THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'CCCD người chồng và người vợ không được trùng nhau.';
    END IF;
END$$

DELIMITER ;

-- =====================================================
-- 6.12 TRIGGER: tg_chungtu_before_insert
-- Trước khi khai tử:
--   • Ngày mất không được sau ngày đăng ký
--   • Ngày mất không được là ngày tương lai
-- =====================================================

DROP TRIGGER IF EXISTS tg_chungtu_before_insert;

DELIMITER $$

CREATE TRIGGER tg_chungtu_before_insert
BEFORE INSERT ON chungtu
FOR EACH ROW
BEGIN
    -- Ngày mất không được là tương lai
    IF NEW.NgayMat > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ngày mất không được là ngày trong tương lai.';
    END IF;

    -- Ngày đăng ký phải sau hoặc bằng ngày mất
    IF NEW.NgayDangKy < NEW.NgayMat THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ngày đăng ký khai tử phải sau hoặc bằng ngày mất.';
    END IF;
END$$

DELIMITER ;

-- =====================================================
-- KIỂM TRA HOẠT ĐỘNG CỦA TRIGGER
-- =====================================================

-- Test 6.1: Thêm nhân khẩu → trigger cập nhật thống kê + ghi log
INSERT INTO nhankhau VALUES (
    'NK00000803', 'Test Trigger', '2000-01-01', 'Nam',
    'Hà Nội', 'Không', 'Kinh', '111222333444',
    'HK00000001', 'Sinh viên'
);

SELECT * FROM thongke_hokhau WHERE MaHoKhau = 'HK00000001';
SELECT * FROM log_nhankhau ORDER BY LogID DESC LIMIT 3;

-- Test 6.2: Cập nhật nghề nghiệp → ghi log
UPDATE nhankhau SET NgheNghiep = 'Kỹ sư' WHERE MaNhanKhau = 'NK00000803';
SELECT * FROM log_nhankhau WHERE MaNhanKhau = 'NK00000803';

-- Test 6.3: Xóa nhân khẩu → trigger giảm thống kê
DELETE FROM nhankhau WHERE MaNhanKhau = 'NK00000803';
SELECT * FROM thongke_hokhau WHERE MaHoKhau = 'HK00000001';

-- Test 6.4: Thêm tiền án → tạo cảnh báo
INSERT INTO tienantiensu VALUES (
    'TS00000121', 'Trộm cắp', 'TAND tỉnh Hà Nội', '2024-01-10', 'NK00000001'
);
SELECT * FROM canhbao_tienantiensu ORDER BY CanhBaoID DESC LIMIT 1;

-- Test 6.5: Thêm tạm trú với thời hạn sai → trigger chặn
-- INSERT INTO tamtru VALUES ('TT99999', 'Nhà trọ X', 'Địa chỉ', '0900000000', '5 tháng', 'NK00000001');
-- => Lỗi: Thời hạn tạm trú không hợp lệ

-- Xem tất cả trigger đã tạo
SHOW TRIGGERS FROM project;
