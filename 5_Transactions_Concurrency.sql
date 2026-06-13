-- =====================================================
-- 5. TRANSACTIONS & CONCURRENCY
-- Hệ thống quản lý nhân khẩu
-- =====================================================

USE project;

-- =====================================================
-- 5.1 TRANSACTION CƠ BẢN - THÊM HỘ KHẨU VÀ NHÂN KHẨU
-- Đảm bảo tính toàn vẹn: nếu thêm hộ khẩu thành công
-- nhưng thêm nhân khẩu thất bại thì rollback cả hai.
-- =====================================================

START TRANSACTION;

INSERT INTO hokhau VALUES (
    'HK00000201', 'Trần Văn Mạnh', '012345678901',
    'Phường 3', 'Số 10, Đường Lê Lợi, Phường 3, Hà Nội', '2024-01-15'
);

INSERT INTO nhankhau VALUES (
    'NK00000801', 'Trần Văn Mạnh', '1985-05-10', 'Nam',
    'Hà Nội', 'Không', 'Kinh', '012345678901',
    'HK00000201', 'Kỹ sư'
);

INSERT INTO nhankhau VALUES (
    'NK00000802', 'Nguyễn Thị Lan', '1988-08-20', 'Nữ',
    'Hà Nội', 'Phật giáo', 'Kinh', '098765432109',
    'HK00000201', 'Giáo viên'
);

COMMIT;

-- =====================================================
-- 5.2 TRANSACTION VỚI ROLLBACK - ĐĂNG KÝ TẠM TRÚ
-- Nếu nhân khẩu không tồn tại thì rollback toàn bộ.
-- =====================================================

START TRANSACTION;

SAVEPOINT sp_before_tamtru;

-- Kiểm tra nhân khẩu tồn tại trước khi thêm tạm trú
-- (trong thực tế dùng ứng dụng hoặc stored procedure)
INSERT INTO tamtru VALUES (
    'TT00000301', 'Nhà trọ Hòa Bình',
    'Số 50, Đường Trần Phú, Phường 2',
    '0912345678', '12 tháng', 'NK00000801'
);

-- Giả lập lỗi: thêm tạm trú với MaNhanKhau không tồn tại
-- INSERT INTO tamtru VALUES ('TT00000302', 'Nhà trọ XYZ', '...', '...', '...', 'NK99999999');
-- => Nếu dòng trên được kích hoạt, ROLLBACK TO sp_before_tamtru

COMMIT;

-- =====================================================
-- 5.3 TRANSACTION VỚI NHIỀU BẢNG - ĐĂNG KÝ KẾT HÔN
-- Ghi nhận kết hôn và cập nhật thông tin tạm trú.
-- =====================================================

START TRANSACTION;

INSERT INTO kethon VALUES (
    'KH00000151',
    'Nguyễn Văn Bình', '1990-03-15', 'Kinh', 'Việt Nam',
    'Số 10, Đường Lê Lợi, Hà Nội', '012111222333',
    'Lê Thị Hoa', '1993-07-22', 'Kinh', 'Việt Nam',
    'Số 20, Đường Trần Phú, Hà Nội', '098111222333',
    'Phường 3', '2024-06-01'
);

-- Đồng thời xóa tạm trú (nếu có) vì đã định cư
DELETE FROM tamtru
WHERE MaNhanKhau IN (
    SELECT MaNhanKhau FROM nhankhau WHERE CCCD IN ('012111222333','098111222333')
);

COMMIT;

-- =====================================================
-- 5.4 TRANSACTION VỚI SAVEPOINT - ĐĂNG KÝ KHAI TỬ
-- Cho phép rollback từng bước nếu có lỗi.
-- =====================================================

START TRANSACTION;

SAVEPOINT sp_chungtu;

INSERT INTO chungtu VALUES (
    'CT00000101',
    'Lê Văn Nam', 'Số 5, Đường Ngô Quyền, Hải Phòng',
    'Con trai', 'Lê Văn Cường', '1935-01-01',
    'Kinh', 'Việt Nam', '001122334455',
    '2024-05-10', '08:30', 'Phường 1', '2024-05-15'
);

SAVEPOINT sp_after_chungtu;

-- Xóa tạm trú của người đã mất (nếu có)
DELETE FROM tamtru
WHERE MaNhanKhau IN (
    SELECT MaNhanKhau FROM nhankhau WHERE CCCD = '001122334455'
);

-- Nếu có lỗi ở bước xóa: ROLLBACK TO sp_after_chungtu
-- Nếu muốn hủy toàn bộ:   ROLLBACK TO sp_chungtu

COMMIT;

-- =====================================================
-- 5.5 ISOLATION LEVEL - ĐỌC DỮ LIỆU NHẤT QUÁN
-- Đặt mức cô lập để tránh dirty read / phantom read.
-- =====================================================

-- Mức mặc định của MySQL (REPEATABLE READ)
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

START TRANSACTION;

-- Session 1: đọc danh sách nhân khẩu theo hộ khẩu
SELECT MaNhanKhau, Ten, NgheNghiep
FROM nhankhau
WHERE MaHoKhau = 'HK00000001';

-- Trong lúc này session khác có thể INSERT nhân khẩu mới vào HK00000001,
-- nhưng với REPEATABLE READ, kết quả ở đây không thay đổi cho đến COMMIT.

COMMIT;

-- READ COMMITTED: thấy được dữ liệu đã commit từ session khác
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

START TRANSACTION;

SELECT COUNT(*) AS SoNhanKhau FROM nhankhau;

-- Có thể thấy INSERT mới từ session khác nếu đã COMMIT

COMMIT;

-- SERIALIZABLE: mức cao nhất, khóa hoàn toàn
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

START TRANSACTION;

SELECT KhuVuc, COUNT(*) AS SoHoKhau
FROM hokhau
GROUP BY KhuVuc;

COMMIT;

-- Khôi phục mặc định
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- =====================================================
-- 5.6 LOCK THỦ CÔNG - TRÁNH RACE CONDITION
-- Khóa hàng khi cập nhật thông tin nhân khẩu.
-- =====================================================

START TRANSACTION;

-- Khóa hàng để cập nhật, ngăn session khác đọc/ghi đồng thời
SELECT MaNhanKhau, Ten, NgheNghiep
FROM nhankhau
WHERE MaNhanKhau = 'NK00000001'
FOR UPDATE;

-- Cập nhật nghề nghiệp sau khi đã khóa
UPDATE nhankhau
SET NgheNghiep = 'Lập trình viên'
WHERE MaNhanKhau = 'NK00000001';

COMMIT;

-- =====================================================
-- 5.7 DEADLOCK PREVENTION - THỨ TỰ TRUY CẬP NHẤT QUÁN
-- Luôn truy cập bảng theo thứ tự: hokhau → nhankhau → tamtru
-- để tránh deadlock giữa các transaction.
-- =====================================================

-- Session A (đúng thứ tự)
START TRANSACTION;
SELECT * FROM hokhau WHERE MaHoKhau = 'HK00000010' FOR UPDATE;
SELECT * FROM nhankhau WHERE MaHoKhau = 'HK00000010' FOR UPDATE;
UPDATE nhankhau SET NgheNghiep = 'Bác sĩ' WHERE MaHoKhau = 'HK00000010';
COMMIT;

-- Session B (luôn cùng thứ tự → không deadlock)
START TRANSACTION;
SELECT * FROM hokhau WHERE MaHoKhau = 'HK00000020' FOR UPDATE;
SELECT * FROM nhankhau WHERE MaHoKhau = 'HK00000020' FOR UPDATE;
UPDATE nhankhau SET NgheNghiep = 'Kỹ sư' WHERE MaHoKhau = 'HK00000020';
COMMIT;

-- =====================================================
-- 5.8 TRANSACTION STORED PROCEDURE
-- Đóng gói logic nghiệp vụ phức tạp vào stored procedure.
-- =====================================================

DROP PROCEDURE IF EXISTS sp_ChuyenHoKhau;

DELIMITER $$

CREATE PROCEDURE sp_ChuyenHoKhau(
    IN p_MaNhanKhau CHAR(10),
    IN p_MaHoKhauMoi CHAR(10)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chuyển hộ khẩu thất bại, đã rollback.';
    END;

    START TRANSACTION;

    -- Kiểm tra hộ khẩu mới tồn tại
    IF NOT EXISTS (SELECT 1 FROM hokhau WHERE MaHoKhau = p_MaHoKhauMoi) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Hộ khẩu đích không tồn tại.';
    END IF;

    -- Cập nhật nhân khẩu sang hộ khẩu mới
    UPDATE nhankhau
    SET MaHoKhau = p_MaHoKhauMoi
    WHERE MaNhanKhau = p_MaNhanKhau;

    -- Xóa tạm trú (đã chuyển về hộ khẩu chính thức)
    DELETE FROM tamtru WHERE MaNhanKhau = p_MaNhanKhau;

    COMMIT;
END$$

DELIMITER ;

-- Gọi thủ tục: chuyển NK00000050 sang HK00000005
CALL sp_ChuyenHoKhau('NK00000050', 'HK00000005');