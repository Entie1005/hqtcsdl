-- =====================================================
-- 4_Stored_Procedures.sql
-- Hệ thống Quản lý Nhân Khẩu
-- Gồm: 20 Stored Procedures cho toàn bộ nghiệp vụ
-- =====================================================

USE project;

DELIMITER $$

-- =====================================================
-- NHÓM 1: HỘ KHẨU (hokhau)
-- SP01 - SP04
-- =====================================================

-- ----------------------------------------------------
-- SP01: Thêm hộ khẩu mới
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ThemHoKhau$$
CREATE PROCEDURE sp_ThemHoKhau (
    IN  p_MaHoKhau   CHAR(10),
    IN  p_TenChuHo   VARCHAR(50),
    IN  p_CCCDChuHo  VARCHAR(20),
    IN  p_KhuVuc     VARCHAR(50),
    IN  p_DiaChiHK   VARCHAR(100),
    IN  p_NgayLap    DATE,
    OUT p_KetQua     VARCHAR(200)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_KetQua = 'LỖI: Xảy ra lỗi khi thêm hộ khẩu.';
    END;

    IF p_MaHoKhau IS NULL OR TRIM(p_MaHoKhau) = '' THEN
        SET p_KetQua = 'LỖI: Mã hộ khẩu không được để trống.';
    ELSEIF EXISTS (SELECT 1 FROM hokhau WHERE MaHoKhau = p_MaHoKhau) THEN
        SET p_KetQua = CONCAT('LỖI: Mã hộ khẩu "', p_MaHoKhau, '" đã tồn tại.');
    ELSEIF EXISTS (SELECT 1 FROM hokhau WHERE CCCDChuHo = p_CCCDChuHo) THEN
        SET p_KetQua = CONCAT('LỖI: CCCD "', p_CCCDChuHo, '" đã được đăng ký cho hộ khẩu khác.');
    ELSE
        START TRANSACTION;
            INSERT INTO hokhau (MaHoKhau, TenChuHo, CCCDChuHo, KhuVuc, DiaChiHK, NgayLap)
            VALUES (p_MaHoKhau, p_TenChuHo, p_CCCDChuHo, p_KhuVuc, p_DiaChiHK, p_NgayLap);
        COMMIT;
        SET p_KetQua = CONCAT('OK: Đã thêm hộ khẩu "', p_MaHoKhau, '" - Chủ hộ: ', p_TenChuHo);
    END IF;
END$$


-- ----------------------------------------------------
-- SP02: Cập nhật thông tin hộ khẩu
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_CapNhatHoKhau$$
CREATE PROCEDURE sp_CapNhatHoKhau (
    IN  p_MaHoKhau   CHAR(10),
    IN  p_TenChuHo   VARCHAR(50),
    IN  p_CCCDChuHo  VARCHAR(20),
    IN  p_KhuVuc     VARCHAR(50),
    IN  p_DiaChiHK   VARCHAR(100),
    OUT p_KetQua     VARCHAR(200)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_KetQua = 'LỖI: Không thể cập nhật hộ khẩu.';
    END;

    IF NOT EXISTS (SELECT 1 FROM hokhau WHERE MaHoKhau = p_MaHoKhau) THEN
        SET p_KetQua = CONCAT('LỖI: Mã hộ khẩu "', p_MaHoKhau, '" không tồn tại.');
    ELSE
        START TRANSACTION;
            UPDATE hokhau
            SET TenChuHo  = COALESCE(NULLIF(p_TenChuHo,  ''), TenChuHo),
                CCCDChuHo = COALESCE(NULLIF(p_CCCDChuHo, ''), CCCDChuHo),
                KhuVuc    = COALESCE(NULLIF(p_KhuVuc,    ''), KhuVuc),
                DiaChiHK  = COALESCE(NULLIF(p_DiaChiHK,  ''), DiaChiHK)
            WHERE MaHoKhau = p_MaHoKhau;
        COMMIT;
        SET p_KetQua = CONCAT('OK: Đã cập nhật hộ khẩu "', p_MaHoKhau, '".');
    END IF;
END$$


-- ----------------------------------------------------
-- SP03: Xóa hộ khẩu (kiểm tra nhân khẩu phụ thuộc)
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_XoaHoKhau$$
CREATE PROCEDURE sp_XoaHoKhau (
    IN  p_MaHoKhau CHAR(10),
    OUT p_KetQua   VARCHAR(200)
)
BEGIN
    DECLARE v_SoNK INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_KetQua = 'LỖI: Không thể xóa hộ khẩu.';
    END;

    IF NOT EXISTS (SELECT 1 FROM hokhau WHERE MaHoKhau = p_MaHoKhau) THEN
        SET p_KetQua = CONCAT('LỖI: Mã hộ khẩu "', p_MaHoKhau, '" không tồn tại.');
    ELSE
        SELECT COUNT(*) INTO v_SoNK FROM nhankhau WHERE MaHoKhau = p_MaHoKhau;
        IF v_SoNK > 0 THEN
            SET p_KetQua = CONCAT('LỖI: Hộ khẩu đang có ', v_SoNK,
                                  ' nhân khẩu. Cần chuyển/xóa nhân khẩu trước.');
        ELSE
            START TRANSACTION;
                DELETE FROM hokhau WHERE MaHoKhau = p_MaHoKhau;
            COMMIT;
            SET p_KetQua = CONCAT('OK: Đã xóa hộ khẩu "', p_MaHoKhau, '".');
        END IF;
    END IF;
END$$


-- ----------------------------------------------------
-- SP04: Thống kê nhân khẩu theo từng khu vực
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ThongKeHoKhauTheoKhuVuc$$
CREATE PROCEDURE sp_ThongKeHoKhauTheoKhuVuc (
    IN p_KhuVuc VARCHAR(50)   -- NULL = lấy tất cả khu vực
)
BEGIN
    SELECT
        hk.KhuVuc,
        COUNT(DISTINCT hk.MaHoKhau)                                     AS SoHoKhau,
        COUNT(nk.MaNhanKhau)                                             AS TongNhanKhau,
        SUM(nk.GioiTinh = 'Nam')                                        AS SoNam,
        SUM(nk.GioiTinh = 'Nữ')                                         AS SoNu,
        ROUND(AVG(TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE())), 1)      AS TuoiTrungBinh,
        SUM(TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE()) < 15)           AS TreEm,
        SUM(TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE()) BETWEEN 15 AND 60) AS LaoDong,
        SUM(TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE()) > 60)           AS NguoiGia
    FROM hokhau hk
    LEFT JOIN nhankhau nk ON hk.MaHoKhau = nk.MaHoKhau
    WHERE (p_KhuVuc IS NULL OR hk.KhuVuc = p_KhuVuc)
    GROUP BY hk.KhuVuc
    ORDER BY TongNhanKhau DESC;
END$$


-- =====================================================
-- NHÓM 2: NHÂN KHẨU (nhankhau)
-- SP05 - SP09
-- =====================================================

-- ----------------------------------------------------
-- SP05: Thêm nhân khẩu mới vào hộ khẩu
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ThemNhanKhau$$
CREATE PROCEDURE sp_ThemNhanKhau (
    IN  p_MaNhanKhau CHAR(10),
    IN  p_Ten        VARCHAR(50),
    IN  p_NgaySinh   DATE,
    IN  p_GioiTinh   VARCHAR(10),
    IN  p_QueQuan    VARCHAR(20),
    IN  p_TonGiao    VARCHAR(20),
    IN  p_DanToc     VARCHAR(20),
    IN  p_CCCD       VARCHAR(20),
    IN  p_MaHoKhau   CHAR(10),
    IN  p_NgheNghiep VARCHAR(100),
    OUT p_KetQua     VARCHAR(200)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_KetQua = 'LỖI: Xảy ra lỗi khi thêm nhân khẩu.';
    END;

    IF EXISTS (SELECT 1 FROM nhankhau WHERE MaNhanKhau = p_MaNhanKhau) THEN
        SET p_KetQua = CONCAT('LỖI: Mã nhân khẩu "', p_MaNhanKhau, '" đã tồn tại.');
    ELSEIF EXISTS (SELECT 1 FROM nhankhau WHERE CCCD = p_CCCD) THEN
        SET p_KetQua = CONCAT('LỖI: CCCD "', p_CCCD, '" đã được đăng ký.');
    ELSEIF p_MaHoKhau IS NOT NULL AND NOT EXISTS (SELECT 1 FROM hokhau WHERE MaHoKhau = p_MaHoKhau) THEN
        SET p_KetQua = CONCAT('LỖI: Hộ khẩu "', p_MaHoKhau, '" không tồn tại.');
    ELSEIF p_NgaySinh > CURDATE() THEN
        SET p_KetQua = 'LỖI: Ngày sinh không hợp lệ (lớn hơn ngày hiện tại).';
    ELSE
        START TRANSACTION;
            INSERT INTO nhankhau
                (MaNhanKhau, Ten, NgaySinh, GioiTinh, QueQuan, TonGiao, DanToc, CCCD, MaHoKhau, NgheNghiep)
            VALUES
                (p_MaNhanKhau, p_Ten, p_NgaySinh, p_GioiTinh, p_QueQuan, p_TonGiao, p_DanToc, p_CCCD, p_MaHoKhau, p_NgheNghiep);
        COMMIT;
        SET p_KetQua = CONCAT('OK: Đã thêm nhân khẩu "', p_Ten, '" vào hộ khẩu ', COALESCE(p_MaHoKhau, 'N/A'));
    END IF;
END$$


-- ----------------------------------------------------
-- SP06: Cập nhật thông tin nhân khẩu
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_CapNhatNhanKhau$$
CREATE PROCEDURE sp_CapNhatNhanKhau (
    IN  p_MaNhanKhau CHAR(10),
    IN  p_Ten        VARCHAR(50),
    IN  p_GioiTinh   VARCHAR(10),
    IN  p_QueQuan    VARCHAR(20),
    IN  p_TonGiao    VARCHAR(20),
    IN  p_DanToc     VARCHAR(20),
    IN  p_NgheNghiep VARCHAR(100),
    IN  p_MaHoKhau   CHAR(10),
    OUT p_KetQua     VARCHAR(200)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_KetQua = 'LỖI: Không thể cập nhật nhân khẩu.';
    END;

    IF NOT EXISTS (SELECT 1 FROM nhankhau WHERE MaNhanKhau = p_MaNhanKhau) THEN
        SET p_KetQua = CONCAT('LỖI: Nhân khẩu "', p_MaNhanKhau, '" không tồn tại.');
    ELSEIF p_MaHoKhau IS NOT NULL AND NOT EXISTS (SELECT 1 FROM hokhau WHERE MaHoKhau = p_MaHoKhau) THEN
        SET p_KetQua = CONCAT('LỖI: Hộ khẩu "', p_MaHoKhau, '" không tồn tại.');
    ELSE
        START TRANSACTION;
            UPDATE nhankhau
            SET Ten        = COALESCE(NULLIF(p_Ten,        ''), Ten),
                GioiTinh   = COALESCE(NULLIF(p_GioiTinh,   ''), GioiTinh),
                QueQuan    = COALESCE(NULLIF(p_QueQuan,    ''), QueQuan),
                TonGiao    = COALESCE(NULLIF(p_TonGiao,    ''), TonGiao),
                DanToc     = COALESCE(NULLIF(p_DanToc,     ''), DanToc),
                NgheNghiep = COALESCE(NULLIF(p_NgheNghiep, ''), NgheNghiep),
                MaHoKhau   = COALESCE(p_MaHoKhau, MaHoKhau)
            WHERE MaNhanKhau = p_MaNhanKhau;
        COMMIT;
        SET p_KetQua = CONCAT('OK: Đã cập nhật nhân khẩu "', p_MaNhanKhau, '".');
    END IF;
END$$


-- ----------------------------------------------------
-- SP07: Xóa nhân khẩu (kiểm tra dữ liệu liên quan)
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_XoaNhanKhau$$
CREATE PROCEDURE sp_XoaNhanKhau (
    IN  p_MaNhanKhau CHAR(10),
    OUT p_KetQua     VARCHAR(200)
)
BEGIN
    DECLARE v_SoTT  INT DEFAULT 0;
    DECLARE v_SoTS  INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_KetQua = 'LỖI: Không thể xóa nhân khẩu.';
    END;

    IF NOT EXISTS (SELECT 1 FROM nhankhau WHERE MaNhanKhau = p_MaNhanKhau) THEN
        SET p_KetQua = CONCAT('LỖI: Nhân khẩu "', p_MaNhanKhau, '" không tồn tại.');
    ELSE
        SELECT COUNT(*) INTO v_SoTT FROM tamtru       WHERE MaNhanKhau = p_MaNhanKhau;
        SELECT COUNT(*) INTO v_SoTS FROM tienantiensu WHERE MaNhanKhau = p_MaNhanKhau;

        IF v_SoTT > 0 OR v_SoTS > 0 THEN
            SET p_KetQua = CONCAT('LỖI: Nhân khẩu đang có ', v_SoTT, ' bản ghi tạm trú và ',
                                   v_SoTS, ' tiền án tiền sự. Hãy xóa dữ liệu liên quan trước.');
        ELSE
            START TRANSACTION;
                DELETE FROM nhankhau WHERE MaNhanKhau = p_MaNhanKhau;
            COMMIT;
            SET p_KetQua = CONCAT('OK: Đã xóa nhân khẩu "', p_MaNhanKhau, '".');
        END IF;
    END IF;
END$$


-- ----------------------------------------------------
-- SP08: Tìm kiếm nhân khẩu (theo tên / CCCD / mã)
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_TimKiemNhanKhau$$
CREATE PROCEDURE sp_TimKiemNhanKhau (
    IN p_TuKhoa VARCHAR(50)
)
BEGIN
    SELECT
        nk.MaNhanKhau,
        nk.Ten,
        nk.NgaySinh,
        TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE()) AS Tuoi,
        nk.GioiTinh,
        nk.CCCD,
        nk.QueQuan,
        nk.TonGiao,
        nk.DanToc,
        nk.NgheNghiep,
        hk.MaHoKhau,
        hk.TenChuHo,
        hk.KhuVuc,
        hk.DiaChiHK
    FROM nhankhau nk
    LEFT JOIN hokhau hk ON nk.MaHoKhau = hk.MaHoKhau
    WHERE nk.MaNhanKhau = p_TuKhoa
       OR nk.CCCD        LIKE CONCAT('%', p_TuKhoa, '%')
       OR nk.Ten         LIKE CONCAT('%', p_TuKhoa, '%')
    ORDER BY nk.Ten;
END$$


-- ----------------------------------------------------
-- SP09: Chuyển nhân khẩu sang hộ khẩu khác
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ChuyenHoKhau$$
CREATE PROCEDURE sp_ChuyenHoKhau (
    IN  p_MaNhanKhau    CHAR(10),
    IN  p_MaHoKhauMoi   CHAR(10),
    OUT p_KetQua        VARCHAR(200)
)
BEGIN
    DECLARE v_MaHoKhauCu CHAR(10);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_KetQua = 'LỖI: Không thể chuyển hộ khẩu.';
    END;

    IF NOT EXISTS (SELECT 1 FROM nhankhau WHERE MaNhanKhau = p_MaNhanKhau) THEN
        SET p_KetQua = CONCAT('LỖI: Nhân khẩu "', p_MaNhanKhau, '" không tồn tại.');
    ELSEIF NOT EXISTS (SELECT 1 FROM hokhau WHERE MaHoKhau = p_MaHoKhauMoi) THEN
        SET p_KetQua = CONCAT('LỖI: Hộ khẩu đích "', p_MaHoKhauMoi, '" không tồn tại.');
    ELSE
        SELECT MaHoKhau INTO v_MaHoKhauCu FROM nhankhau WHERE MaNhanKhau = p_MaNhanKhau;

        IF v_MaHoKhauCu = p_MaHoKhauMoi THEN
            SET p_KetQua = 'LỖI: Nhân khẩu đã thuộc hộ khẩu này rồi.';
        ELSE
            START TRANSACTION;
                UPDATE nhankhau SET MaHoKhau = p_MaHoKhauMoi WHERE MaNhanKhau = p_MaNhanKhau;
            COMMIT;
            SET p_KetQua = CONCAT('OK: Đã chuyển nhân khẩu "', p_MaNhanKhau,
                                   '" từ hộ khẩu "', COALESCE(v_MaHoKhauCu,'N/A'),
                                   '" sang "', p_MaHoKhauMoi, '".');
        END IF;
    END IF;
END$$


-- =====================================================
-- NHÓM 3: TẠM TRÚ (tamtru)
-- SP10 - SP12
-- =====================================================

-- ----------------------------------------------------
-- SP10: Đăng ký tạm trú
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_DangKyTamTru$$
CREATE PROCEDURE sp_DangKyTamTru (
    IN  p_MaTamTru      CHAR(10),
    IN  p_TenNoiTamTru  VARCHAR(50),
    IN  p_DiaChi        VARCHAR(100),
    IN  p_SoDienThoai   CHAR(10),
    IN  p_ThoiHan       CHAR(10),
    IN  p_MaNhanKhau    CHAR(10),
    OUT p_KetQua        VARCHAR(200)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_KetQua = 'LỖI: Không thể đăng ký tạm trú.';
    END;

    IF EXISTS (SELECT 1 FROM tamtru WHERE MaTamTru = p_MaTamTru) THEN
        SET p_KetQua = CONCAT('LỖI: Mã tạm trú "', p_MaTamTru, '" đã tồn tại.');
    ELSEIF NOT EXISTS (SELECT 1 FROM nhankhau WHERE MaNhanKhau = p_MaNhanKhau) THEN
        SET p_KetQua = CONCAT('LỖI: Nhân khẩu "', p_MaNhanKhau, '" không tồn tại.');
    ELSE
        START TRANSACTION;
            INSERT INTO tamtru (MaTamTru, TenNoiTamTru, DiaChi, SoDienThoai, ThoiHan, MaNhanKhau)
            VALUES (p_MaTamTru, p_TenNoiTamTru, p_DiaChi, p_SoDienThoai, p_ThoiHan, p_MaNhanKhau);
        COMMIT;
        SET p_KetQua = CONCAT('OK: Đã đăng ký tạm trú cho nhân khẩu "', p_MaNhanKhau, '".');
    END IF;
END$$


-- ----------------------------------------------------
-- SP11: Hủy đăng ký tạm trú
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_HuyTamTru$$
CREATE PROCEDURE sp_HuyTamTru (
    IN  p_MaTamTru CHAR(10),
    OUT p_KetQua   VARCHAR(200)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_KetQua = 'LỖI: Không thể hủy tạm trú.';
    END;

    IF NOT EXISTS (SELECT 1 FROM tamtru WHERE MaTamTru = p_MaTamTru) THEN
        SET p_KetQua = CONCAT('LỖI: Mã tạm trú "', p_MaTamTru, '" không tồn tại.');
    ELSE
        START TRANSACTION;
            DELETE FROM tamtru WHERE MaTamTru = p_MaTamTru;
        COMMIT;
        SET p_KetQua = CONCAT('OK: Đã hủy đăng ký tạm trú "', p_MaTamTru, '".');
    END IF;
END$$


-- ----------------------------------------------------
-- SP12: Danh sách người tạm trú theo khu vực
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_DanhSachTamTruTheoKhuVuc$$
CREATE PROCEDURE sp_DanhSachTamTruTheoKhuVuc (
    IN p_KhuVuc VARCHAR(50)
)
BEGIN
    SELECT
        tt.MaTamTru,
        tt.TenNoiTamTru,
        tt.DiaChi         AS DiaChiTamTru,
        tt.SoDienThoai,
        tt.ThoiHan,
        nk.MaNhanKhau,
        nk.Ten,
        nk.NgaySinh,
        nk.CCCD,
        nk.GioiTinh,
        hk.KhuVuc
    FROM tamtru tt
    JOIN nhankhau nk ON tt.MaNhanKhau = nk.MaNhanKhau
    LEFT JOIN hokhau hk ON nk.MaHoKhau = hk.MaHoKhau
    WHERE (p_KhuVuc IS NULL OR hk.KhuVuc = p_KhuVuc)
    ORDER BY hk.KhuVuc, nk.Ten;
END$$


-- =====================================================
-- NHÓM 4: TIỀN ÁN TIỀN SỰ (tienantiensu)
-- SP13 - SP14
-- =====================================================

-- ----------------------------------------------------
-- SP13: Thêm tiền án tiền sự
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ThemTienAnTienSu$$
CREATE PROCEDURE sp_ThemTienAnTienSu (
    IN  p_MaTienAnTienSu  CHAR(10),
    IN  p_TenTienAnTienSu VARCHAR(50),
    IN  p_NoiXetXu        VARCHAR(100),
    IN  p_NgayThucThi     DATE,
    IN  p_MaNhanKhau      CHAR(10),
    OUT p_KetQua          VARCHAR(200)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_KetQua = 'LỖI: Không thể thêm tiền án tiền sự.';
    END;

    IF EXISTS (SELECT 1 FROM tienantiensu WHERE MaTienAnTienSu = p_MaTienAnTienSu) THEN
        SET p_KetQua = CONCAT('LỖI: Mã tiền án "', p_MaTienAnTienSu, '" đã tồn tại.');
    ELSEIF NOT EXISTS (SELECT 1 FROM nhankhau WHERE MaNhanKhau = p_MaNhanKhau) THEN
        SET p_KetQua = CONCAT('LỖI: Nhân khẩu "', p_MaNhanKhau, '" không tồn tại.');
    ELSEIF p_NgayThucThi > CURDATE() THEN
        SET p_KetQua = 'LỖI: Ngày thực thi không hợp lệ (lớn hơn ngày hiện tại).';
    ELSE
        START TRANSACTION;
            INSERT INTO tienantiensu (MaTienAnTienSu, TenTienAnTienSu, NoiXetXu, NgayThucThi, MaNhanKhau)
            VALUES (p_MaTienAnTienSu, p_TenTienAnTienSu, p_NoiXetXu, p_NgayThucThi, p_MaNhanKhau);
        COMMIT;
        SET p_KetQua = CONCAT('OK: Đã thêm tiền án tiền sự cho nhân khẩu "', p_MaNhanKhau, '".');
    END IF;
END$$


-- ----------------------------------------------------
-- SP14: Tra cứu tiền án tiền sự theo CCCD hoặc tên
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_TraCuuTienAnTienSu$$
CREATE PROCEDURE sp_TraCuuTienAnTienSu (
    IN p_TuKhoa VARCHAR(50)
)
BEGIN
    SELECT
        nk.MaNhanKhau,
        nk.Ten,
        nk.NgaySinh,
        nk.CCCD,
        hk.KhuVuc,
        ts.MaTienAnTienSu,
        ts.TenTienAnTienSu  AS LoaiViPham,
        ts.NoiXetXu,
        ts.NgayThucThi,
        TIMESTAMPDIFF(YEAR, ts.NgayThucThi, CURDATE()) AS SoNamDa
    FROM tienantiensu ts
    JOIN nhankhau nk ON ts.MaNhanKhau = nk.MaNhanKhau
    LEFT JOIN hokhau hk ON nk.MaHoKhau = hk.MaHoKhau
    WHERE nk.CCCD = p_TuKhoa
       OR nk.Ten  LIKE CONCAT('%', p_TuKhoa, '%')
       OR nk.MaNhanKhau = p_TuKhoa
    ORDER BY ts.NgayThucThi DESC;
END$$


-- =====================================================
-- NHÓM 5: KẾT HÔN (kethon)
-- SP15 - SP16
-- =====================================================

-- ----------------------------------------------------
-- SP15: Đăng ký kết hôn
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_DangKyKetHon$$
CREATE PROCEDURE sp_DangKyKetHon (
    IN  p_MaKetHon          CHAR(10),
    IN  p_TenChong          VARCHAR(50),
    IN  p_NgaySinhChong     DATE,
    IN  p_DanTocChong       VARCHAR(20),
    IN  p_QuocTichChong     VARCHAR(20),
    IN  p_ThuongTamTruChong VARCHAR(100),
    IN  p_CCCDChong         VARCHAR(20),
    IN  p_TenVo             VARCHAR(50),
    IN  p_NgaySinhVo        DATE,
    IN  p_DanTocVo          VARCHAR(20),
    IN  p_QuocTichVo        VARCHAR(20),
    IN  p_ThuongTamTruVo    VARCHAR(100),
    IN  p_CCCDVo            VARCHAR(20),
    IN  p_KhuVucDangKy      VARCHAR(20),
    IN  p_NgayDangKy        DATE,
    OUT p_KetQua            VARCHAR(200)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_KetQua = 'LỖI: Không thể đăng ký kết hôn.';
    END;

    IF EXISTS (SELECT 1 FROM kethon WHERE MaKetHon = p_MaKetHon) THEN
        SET p_KetQua = CONCAT('LỖI: Mã kết hôn "', p_MaKetHon, '" đã tồn tại.');
    ELSEIF p_CCCDChong = p_CCCDVo THEN
        SET p_KetQua = 'LỖI: CCCD chồng và vợ không được trùng nhau.';
    ELSEIF EXISTS (SELECT 1 FROM kethon WHERE CCCDChong = p_CCCDChong OR CCCDVo = p_CCCDChong) THEN
        SET p_KetQua = CONCAT('LỖI: CCCD chồng "', p_CCCDChong, '" đã có hồ sơ kết hôn.');
    ELSEIF EXISTS (SELECT 1 FROM kethon WHERE CCCDVo = p_CCCDVo OR CCCDChong = p_CCCDVo) THEN
        SET p_KetQua = CONCAT('LỖI: CCCD vợ "', p_CCCDVo, '" đã có hồ sơ kết hôn.');
    ELSE
        START TRANSACTION;
            INSERT INTO kethon VALUES (
                p_MaKetHon, p_TenChong, p_NgaySinhChong, p_DanTocChong,
                p_QuocTichChong, p_ThuongTamTruChong, p_CCCDChong,
                p_TenVo, p_NgaySinhVo, p_DanTocVo, p_QuocTichVo,
                p_ThuongTamTruVo, p_CCCDVo, p_KhuVucDangKy, p_NgayDangKy
            );
        COMMIT;
        SET p_KetQua = CONCAT('OK: Đã đăng ký kết hôn cho "', p_TenChong, '" và "', p_TenVo, '".');
    END IF;
END$$


-- ----------------------------------------------------
-- SP16: Tìm kiếm hồ sơ kết hôn theo CCCD hoặc tên
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_TimKiemKetHon$$
CREATE PROCEDURE sp_TimKiemKetHon (
    IN p_TuKhoa VARCHAR(50)
)
BEGIN
    SELECT
        MaKetHon,
        TenChong,
        NgaySinhChong,
        DanTocChong,
        QuocTichChong,
        ThuongTamTruChong,
        CCCDChong,
        TenVo,
        NgaySinhVo,
        DanTocVo,
        QuocTichVo,
        ThuongTamTruVo,
        CCCDVo,
        KhuVucDangKy,
        NgayDangKy,
        TIMESTAMPDIFF(YEAR, NgayDangKy, CURDATE()) AS SoNamKetHon
    FROM kethon
    WHERE TenChong   LIKE CONCAT('%', p_TuKhoa, '%')
       OR TenVo      LIKE CONCAT('%', p_TuKhoa, '%')
       OR CCCDChong  = p_TuKhoa
       OR CCCDVo     = p_TuKhoa
    ORDER BY NgayDangKy DESC;
END$$


-- =====================================================
-- NHÓM 6: CHỨNG TỪ KHAI TỬ (chungtu)
-- SP17 - SP18
-- =====================================================

-- ----------------------------------------------------
-- SP17: Đăng ký khai tử
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_DangKyKhaiTu$$
CREATE PROCEDURE sp_DangKyKhaiTu (
    IN  p_MaChungTu         CHAR(10),
    IN  p_TenNguoiKhai      VARCHAR(50),
    IN  p_ThuongTamTru      VARCHAR(100),
    IN  p_QuanHeVoiNguoiMat VARCHAR(20),
    IN  p_TenNguoiMat       VARCHAR(50),
    IN  p_NgaySinh          DATE,
    IN  p_DanToc            VARCHAR(20),
    IN  p_QuocTich          VARCHAR(20),
    IN  p_CCCD              VARCHAR(20),
    IN  p_NgayMat           DATE,
    IN  p_GioMat            CHAR(5),
    IN  p_KhuVucDangKy      VARCHAR(20),
    IN  p_NgayDangKy        DATE,
    OUT p_KetQua            VARCHAR(200)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_KetQua = 'LỖI: Không thể đăng ký khai tử.';
    END;

    IF EXISTS (SELECT 1 FROM chungtu WHERE MaChungTu = p_MaChungTu) THEN
        SET p_KetQua = CONCAT('LỖI: Mã chứng từ "', p_MaChungTu, '" đã tồn tại.');
    ELSEIF EXISTS (SELECT 1 FROM chungtu WHERE CCCD = p_CCCD) THEN
        SET p_KetQua = CONCAT('LỖI: CCCD "', p_CCCD, '" đã có chứng từ khai tử.');
    ELSEIF p_NgayMat > CURDATE() THEN
        SET p_KetQua = 'LỖI: Ngày mất không hợp lệ (lớn hơn ngày hiện tại).';
    ELSEIF p_NgayDangKy < p_NgayMat THEN
        SET p_KetQua = 'LỖI: Ngày đăng ký không thể trước ngày mất.';
    ELSE
        START TRANSACTION;
            INSERT INTO chungtu VALUES (
                p_MaChungTu, p_TenNguoiKhai, p_ThuongTamTru,
                p_QuanHeVoiNguoiMat, p_TenNguoiMat, p_NgaySinh,
                p_DanToc, p_QuocTich, p_CCCD,
                p_NgayMat, p_GioMat, p_KhuVucDangKy, p_NgayDangKy
            );
        COMMIT;
        SET p_KetQua = CONCAT('OK: Đã đăng ký khai tử cho "', p_TenNguoiMat,
                               '", ngày mất: ', p_NgayMat);
    END IF;
END$$


-- ----------------------------------------------------
-- SP18: Báo cáo tử vong theo năm và khu vực
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_BaoCaoTuVong$$
CREATE PROCEDURE sp_BaoCaoTuVong (
    IN p_Nam    INT,
    IN p_KhuVuc VARCHAR(20)   -- NULL = tất cả
)
BEGIN
    SELECT
        KhuVucDangKy,
        YEAR(NgayMat)   AS Nam,
        MONTH(NgayMat)  AS Thang,
        COUNT(*)        AS SoNguoiMat,
        AVG(TIMESTAMPDIFF(YEAR, NgaySinh, NgayMat)) AS TuoiTrungBinhKhiMat
    FROM chungtu
    WHERE (p_Nam    IS NULL OR YEAR(NgayMat)   = p_Nam)
      AND (p_KhuVuc IS NULL OR KhuVucDangKy    = p_KhuVuc)
    GROUP BY KhuVucDangKy, YEAR(NgayMat), MONTH(NgayMat)
    ORDER BY KhuVucDangKy, Nam, Thang;
END$$


-- =====================================================
-- NHÓM 7: CÁN BỘ (canbo)
-- SP19 - SP20
-- =====================================================

-- ----------------------------------------------------
-- SP19: Đăng nhập cán bộ
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_DangNhap$$
CREATE PROCEDURE sp_DangNhap (
    IN  p_TaiKhoan CHAR(20),
    IN  p_MatKhau  CHAR(20),
    OUT p_KetQua   VARCHAR(50)
)
BEGIN
    IF EXISTS (SELECT 1 FROM canbo WHERE TaiKhoan = p_TaiKhoan AND MatKhau = p_MatKhau) THEN
        SET p_KetQua = 'THANH_CONG';
    ELSEIF EXISTS (SELECT 1 FROM canbo WHERE TaiKhoan = p_TaiKhoan) THEN
        SET p_KetQua = 'SAI_MAT_KHAU';
    ELSE
        SET p_KetQua = 'TAI_KHOAN_KHONG_TON_TAI';
    END IF;
END$$


-- ----------------------------------------------------
-- SP20: Đổi mật khẩu cán bộ
-- ----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_DoiMatKhau$$
CREATE PROCEDURE sp_DoiMatKhau (
    IN  p_TaiKhoan    CHAR(20),
    IN  p_MatKhauCu   CHAR(20),
    IN  p_MatKhauMoi  CHAR(20),
    OUT p_KetQua      VARCHAR(200)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_KetQua = 'LỖI: Không thể đổi mật khẩu.';
    END;

    IF NOT EXISTS (SELECT 1 FROM canbo WHERE TaiKhoan = p_TaiKhoan) THEN
        SET p_KetQua = 'LỖI: Tài khoản không tồn tại.';
    ELSEIF NOT EXISTS (SELECT 1 FROM canbo WHERE TaiKhoan = p_TaiKhoan AND MatKhau = p_MatKhauCu) THEN
        SET p_KetQua = 'LỖI: Mật khẩu cũ không đúng.';
    ELSEIF p_MatKhauMoi = p_MatKhauCu THEN
        SET p_KetQua = 'LỖI: Mật khẩu mới phải khác mật khẩu cũ.';
    ELSEIF LENGTH(p_MatKhauMoi) < 6 THEN
        SET p_KetQua = 'LỖI: Mật khẩu mới phải có ít nhất 6 ký tự.';
    ELSE
        START TRANSACTION;
            UPDATE canbo SET MatKhau = p_MatKhauMoi WHERE TaiKhoan = p_TaiKhoan;
        COMMIT;
        SET p_KetQua = CONCAT('OK: Đã đổi mật khẩu cho tài khoản "', p_TaiKhoan, '".');
    END IF;
END$$

DELIMITER ;

-- =====================================================
-- HƯỚNG DẪN SỬ DỤNG
-- =====================================================
/*
== NHÓM 1: HỘ KHẨU ==
CALL sp_ThemHoKhau('HK00000999','Nguyễn Văn A','012345678901','Phường 1','Số 1 Lê Lợi','2024-01-01',@kq); SELECT @kq;
CALL sp_CapNhatHoKhau('HK00000001','Nguyễn Văn B','','','',@kq);                                          SELECT @kq;
CALL sp_XoaHoKhau('HK00000999',@kq);                                                                       SELECT @kq;
CALL sp_ThongKeHoKhauTheoKhuVuc(NULL);   -- tất cả khu vực
CALL sp_ThongKeHoKhauTheoKhuVuc('Phường 1');

== NHÓM 2: NHÂN KHẨU ==
CALL sp_ThemNhanKhau('NK00000999','Lê Thị B','2000-05-10','Nữ','Hà Nội','Không','Kinh','098765432100','HK00000001','Giáo viên',@kq); SELECT @kq;
CALL sp_CapNhatNhanKhau('NK00000001','','','','','','Bác sĩ',NULL,@kq); SELECT @kq;
CALL sp_XoaNhanKhau('NK00000999',@kq);                                  SELECT @kq;
CALL sp_TimKiemNhanKhau('Nguyễn');
CALL sp_ChuyenHoKhau('NK00000001','HK00000002',@kq);                    SELECT @kq;

== NHÓM 3: TẠM TRÚ ==
CALL sp_DangKyTamTru('TT00000999','Nhà trọ A','Số 5 Trần Phú','0901234567','6 tháng','NK00000001',@kq); SELECT @kq;
CALL sp_HuyTamTru('TT00000999',@kq);                                                                     SELECT @kq;
CALL sp_DanhSachTamTruTheoKhuVuc('Phường 1');
CALL sp_DanhSachTamTruTheoKhuVuc(NULL);   -- tất cả

== NHÓM 4: TIỀN ÁN TIỀN SỰ ==
CALL sp_ThemTienAnTienSu('TS00000999','Trộm cắp','TAND Hà Nội','2020-03-15','NK00000001',@kq); SELECT @kq;
CALL sp_TraCuuTienAnTienSu('Nguyễn');

== NHÓM 5: KẾT HÔN ==
CALL sp_TimKiemKetHon('Nguyễn');

== NHÓM 6: KHAI TỬ ==
CALL sp_BaoCaoTuVong(2022, NULL);
CALL sp_BaoCaoTuVong(NULL, 'Phường 1');

== NHÓM 7: CÁN BỘ ==
CALL sp_DangNhap('canbo01','Cb@1234',@kq);         SELECT @kq;
CALL sp_DoiMatKhau('canbo01','Cb@1234','Cb@9999',@kq); SELECT @kq;
*/
