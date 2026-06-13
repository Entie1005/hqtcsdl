-- =====================================================
-- 7. OPTIMIZATION
-- Hệ thống quản lý nhân khẩu
-- =====================================================

USE project;

-- =====================================================
-- 7.1 PHÂN TÍCH QUERY HIỆN TẠI VỚI EXPLAIN
-- Dùng EXPLAIN để xem query plan trước khi tối ưu.
-- =====================================================

-- 7.1.1 Tìm nhân khẩu theo khu vực (chưa có index composite)
EXPLAIN SELECT n.MaNhanKhau, n.Ten, n.NgheNghiep, h.KhuVuc
FROM nhankhau n
JOIN hokhau h ON n.MaHoKhau = h.MaHoKhau
WHERE h.KhuVuc = 'Phường 3';

-- 7.1.2 Tìm nhân khẩu có tiền án tiền sự
EXPLAIN SELECT n.MaNhanKhau, n.Ten, t.TenTienAnTienSu, t.NgayThucThi
FROM nhankhau n
JOIN tienantiensu t ON n.MaNhanKhau = t.MaNhanKhau
WHERE t.NgayThucThi BETWEEN '2010-01-01' AND '2023-12-31';

-- 7.1.3 Tìm người đang tạm trú tại một địa chỉ cụ thể
EXPLAIN SELECT n.Ten, n.CCCD, tt.TenNoiTamTru, tt.ThoiHan
FROM tamtru tt
JOIN nhankhau n ON tt.MaNhanKhau = n.MaNhanKhau
WHERE tt.TenNoiTamTru = 'Nhà trọ Hoàng Anh';

-- 7.1.4 Thống kê số nhân khẩu theo nghề nghiệp
EXPLAIN SELECT NgheNghiep, COUNT(*) AS SoNguoi
FROM nhankhau
GROUP BY NgheNghiep
ORDER BY SoNguoi DESC;

-- 7.1.5 Tìm kiếm theo CCCD (full-text scan nếu chưa có index)
EXPLAIN SELECT * FROM nhankhau WHERE CCCD = '009010016761';

-- =====================================================
-- 7.2 INDEX ĐƠN (SINGLE-COLUMN INDEX)
-- Tăng tốc các truy vấn lọc theo một cột thường dùng.
-- =====================================================

-- Xóa index cũ nếu tồn tại trước khi tạo lại
DROP INDEX IF EXISTS idx_nhankhau_ten         ON nhankhau;
DROP INDEX IF EXISTS idx_nhankhau_nghenghiep  ON nhankhau;
DROP INDEX IF EXISTS idx_nhankhau_gioitinh    ON nhankhau;
DROP INDEX IF EXISTS idx_nhankhau_dantoc      ON nhankhau;
DROP INDEX IF EXISTS idx_nhankhau_tongiao     ON nhankhau;
DROP INDEX IF EXISTS idx_tamtru_thoihan       ON tamtru;
DROP INDEX IF EXISTS idx_tamtru_tennoi        ON tamtru;
DROP INDEX IF EXISTS idx_tienantiensu_loai    ON tienantiensu;
DROP INDEX IF EXISTS idx_tienantiensu_ngay    ON tienantiensu;
DROP INDEX IF EXISTS idx_kethon_ngaydangky    ON kethon;
DROP INDEX IF EXISTS idx_kethon_khuvuc        ON kethon;
DROP INDEX IF EXISTS idx_chungtu_ngaymat      ON chungtu;
DROP INDEX IF EXISTS idx_chungtu_khuvuc       ON chungtu;
DROP INDEX IF EXISTS idx_hokhau_ngaylap       ON hokhau;

-- Nhân khẩu: tìm theo tên, nghề nghiệp, giới tính, dân tộc, tôn giáo
CREATE INDEX idx_nhankhau_ten        ON nhankhau (Ten);
CREATE INDEX idx_nhankhau_nghenghiep ON nhankhau (NgheNghiep);
CREATE INDEX idx_nhankhau_gioitinh   ON nhankhau (GioiTinh);
CREATE INDEX idx_nhankhau_dantoc     ON nhankhau (DanToc);
CREATE INDEX idx_nhankhau_tongiao    ON nhankhau (TonGiao);

-- Tạm trú: tìm theo thời hạn, tên nơi tạm trú
CREATE INDEX idx_tamtru_thoihan  ON tamtru (ThoiHan);
CREATE INDEX idx_tamtru_tennoi   ON tamtru (TenNoiTamTru);

-- Tiền án tiền sự: tìm theo loại vụ án, ngày thực thi
CREATE INDEX idx_tienantiensu_loai ON tienantiensu (TenTienAnTienSu);
CREATE INDEX idx_tienantiensu_ngay ON tienantiensu (NgayThucThi);

-- Kết hôn: tìm theo ngày đăng ký, khu vực
CREATE INDEX idx_kethon_ngaydangky ON kethon (NgayDangKy);
CREATE INDEX idx_kethon_khuvuc     ON kethon (KhuVucDangKy);

-- Chứng từ khai tử: tìm theo ngày mất, khu vực
CREATE INDEX idx_chungtu_ngaymat ON chungtu (NgayMat);
CREATE INDEX idx_chungtu_khuvuc  ON chungtu (KhuVucDangKy);

-- Hộ khẩu: tìm theo ngày lập
CREATE INDEX idx_hokhau_ngaylap ON hokhau (NgayLap);

-- =====================================================
-- 7.3 INDEX COMPOSITE (MULTI-COLUMN INDEX)
-- Tăng tốc các truy vấn lọc hoặc JOIN nhiều cột cùng lúc.
-- =====================================================

DROP INDEX IF EXISTS idx_nk_hokhau_ten           ON nhankhau;
DROP INDEX IF EXISTS idx_nk_hokhau_nghenghiep     ON nhankhau;
DROP INDEX IF EXISTS idx_nk_gioitinh_ngaysinh     ON nhankhau;
DROP INDEX IF EXISTS idx_nk_dantoc_tongiao        ON nhankhau;
DROP INDEX IF EXISTS idx_tt_nhankhau_thoihan      ON tamtru;
DROP INDEX IF EXISTS idx_ts_nhankhau_ngay         ON tienantiensu;
DROP INDEX IF EXISTS idx_kh_khuvuc_ngaydangky     ON kethon;
DROP INDEX IF EXISTS idx_ct_khuvuc_ngaymat        ON chungtu;

-- nhankhau: JOIN theo hộ khẩu + lọc tên
CREATE INDEX idx_nk_hokhau_ten        ON nhankhau (MaHoKhau, Ten);

-- nhankhau: lọc theo hộ khẩu + nghề nghiệp
CREATE INDEX idx_nk_hokhau_nghenghiep ON nhankhau (MaHoKhau, NgheNghiep);

-- nhankhau: thống kê giới tính + nhóm tuổi
CREATE INDEX idx_nk_gioitinh_ngaysinh ON nhankhau (GioiTinh, NgaySinh);

-- nhankhau: báo cáo dân tộc + tôn giáo
CREATE INDEX idx_nk_dantoc_tongiao    ON nhankhau (DanToc, TonGiao);

-- tamtru: JOIN nhân khẩu + lọc thời hạn
CREATE INDEX idx_tt_nhankhau_thoihan  ON tamtru (MaNhanKhau, ThoiHan);

-- tienantiensu: JOIN nhân khẩu + lọc ngày
CREATE INDEX idx_ts_nhankhau_ngay     ON tienantiensu (MaNhanKhau, NgayThucThi);

-- kethon: lọc khu vực + thống kê theo năm
CREATE INDEX idx_kh_khuvuc_ngaydangky ON kethon (KhuVucDangKy, NgayDangKy);

-- chungtu: báo cáo theo khu vực + ngày mất
CREATE INDEX idx_ct_khuvuc_ngaymat    ON chungtu (KhuVucDangKy, NgayMat);

-- =====================================================
-- 7.4 COVERING INDEX
-- Index bao gồm đủ cột cần SELECT → không cần truy cập bảng chính.
-- =====================================================

DROP INDEX IF EXISTS idx_cov_nk_thongke   ON nhankhau;
DROP INDEX IF EXISTS idx_cov_nk_baocao    ON nhankhau;
DROP INDEX IF EXISTS idx_cov_tt_danhsach  ON tamtru;

-- Bao phủ query thống kê nhân khẩu theo hộ khẩu + nghề nghiệp
-- SELECT MaHoKhau, NgheNghiep, COUNT(*) → chỉ đọc index
CREATE INDEX idx_cov_nk_thongke
    ON nhankhau (MaHoKhau, NgheNghiep, GioiTinh);

-- Bao phủ báo cáo danh sách: Ten + NgaySinh + GioiTinh theo hộ khẩu
CREATE INDEX idx_cov_nk_baocao
    ON nhankhau (MaHoKhau, Ten, NgaySinh, GioiTinh);

-- Bao phủ danh sách tạm trú: SELECT MaNhanKhau, TenNoiTamTru, ThoiHan
CREATE INDEX idx_cov_tt_danhsach
    ON tamtru (MaNhanKhau, TenNoiTamTru, ThoiHan);

-- =====================================================
-- 7.5 VERIFY INDEX VỚI EXPLAIN (SAU KHI TẠO INDEX)
-- So sánh với kết quả ở mục 7.1.
-- =====================================================

-- 7.5.1 Sau khi tạo index: type nên là ref thay vì ALL
EXPLAIN SELECT n.MaNhanKhau, n.Ten, n.NgheNghiep, h.KhuVuc
FROM nhankhau n
JOIN hokhau h ON n.MaHoKhau = h.MaHoKhau
WHERE h.KhuVuc = 'Phường 3';

-- 7.5.2 Dùng covering index: Extra = "Using index"
EXPLAIN SELECT MaHoKhau, NgheNghiep, GioiTinh
FROM nhankhau
WHERE MaHoKhau = 'HK00000010';

-- 7.5.3 Tìm tiền án theo khoảng ngày: dùng idx_tienantiensu_ngay
EXPLAIN SELECT MaNhanKhau, TenTienAnTienSu, NgayThucThi
FROM tienantiensu
WHERE NgayThucThi BETWEEN '2015-01-01' AND '2020-12-31';

-- 7.5.4 Thống kê không cần filesort: dùng idx_nk_dantoc_tongiao
EXPLAIN SELECT DanToc, TonGiao, COUNT(*) AS SoNguoi
FROM nhankhau
GROUP BY DanToc, TonGiao;

-- =====================================================
-- 7.6 TỐI ƯU QUERY - VIẾT LẠI CÂU TRUY VẤN HIỆU QUẢ HƠN
-- =====================================================

-- -------------------------------------------------------
-- 7.6.1 TRÁNH SELECT * — chỉ lấy cột cần thiết
-- -------------------------------------------------------

-- Xấu: quét toàn bộ cột, không dùng covering index
-- SELECT * FROM nhankhau WHERE MaHoKhau = 'HK00000010';

-- Tốt: chỉ lấy cột cần dùng
SELECT MaNhanKhau, Ten, NgaySinh, GioiTinh, NgheNghiep
FROM nhankhau
WHERE MaHoKhau = 'HK00000010';

-- -------------------------------------------------------
-- 7.6.2 TRÁNH FUNCTION TRÊN CỘT ĐƯỢC INDEX
-- -------------------------------------------------------

-- Xấu: YEAR() phá index trên NgaySinh
-- SELECT * FROM nhankhau WHERE YEAR(NgaySinh) = 1990;

-- Tốt: dùng khoảng giá trị để tận dụng index
SELECT MaNhanKhau, Ten, NgaySinh
FROM nhankhau
WHERE NgaySinh BETWEEN '1990-01-01' AND '1990-12-31';

-- -------------------------------------------------------
-- 7.6.3 TRÁNH LIKE DẦU '%' Ở ĐẦU CHUỖI
-- -------------------------------------------------------

-- Xấu: không dùng được index
-- SELECT * FROM nhankhau WHERE Ten LIKE '%Lan%';

-- Tốt: LIKE tiền tố dùng được index idx_nhankhau_ten
SELECT MaNhanKhau, Ten, MaHoKhau
FROM nhankhau
WHERE Ten LIKE 'Nguyễn%';

-- -------------------------------------------------------
-- 7.6.4 DÙNG EXISTS THAY CHO IN (VỚI SUBQUERY LỚN)
-- -------------------------------------------------------

-- Chậm hơn khi subquery trả về nhiều hàng
-- SELECT * FROM nhankhau
-- WHERE MaNhanKhau IN (SELECT MaNhanKhau FROM tienantiensu);

-- Nhanh hơn: dừng ngay khi tìm thấy kết quả đầu tiên
SELECT n.MaNhanKhau, n.Ten, n.MaHoKhau
FROM nhankhau n
WHERE EXISTS (
    SELECT 1 FROM tienantiensu t
    WHERE t.MaNhanKhau = n.MaNhanKhau
);

-- -------------------------------------------------------
-- 7.6.5 DÙNG JOIN THAY CHO SUBQUERY TRONG SELECT
-- -------------------------------------------------------

-- Chậm: correlated subquery chạy lại từng hàng
-- SELECT MaHoKhau, TenChuHo,
--        (SELECT COUNT(*) FROM nhankhau n WHERE n.MaHoKhau = h.MaHoKhau) AS SoNK
-- FROM hokhau h;

-- Nhanh hơn: tính toán một lần bằng GROUP BY + JOIN
SELECT h.MaHoKhau, h.TenChuHo, h.KhuVuc,
       COALESCE(nk.SoNK, 0) AS SoNhanKhau
FROM hokhau h
LEFT JOIN (
    SELECT MaHoKhau, COUNT(*) AS SoNK
    FROM nhankhau
    GROUP BY MaHoKhau
) nk ON h.MaHoKhau = nk.MaHoKhau
ORDER BY SoNhanKhau DESC;

-- -------------------------------------------------------
-- 7.6.6 LIMIT SỚM TRONG SUBQUERY KHI CHỈ CẦN TOP N
-- -------------------------------------------------------

-- Lấy 10 hộ khẩu nhiều nhân khẩu nhất
SELECT h.MaHoKhau, h.TenChuHo, h.KhuVuc, COUNT(n.MaNhanKhau) AS SoNK
FROM hokhau h
JOIN nhankhau n ON h.MaHoKhau = n.MaHoKhau
GROUP BY h.MaHoKhau, h.TenChuHo, h.KhuVuc
ORDER BY SoNK DESC
LIMIT 10;

-- -------------------------------------------------------
-- 7.6.7 TRÁNH OR TRÊN NHIỀU CỘT KHÁC NHAU (DÙNG UNION)
-- -------------------------------------------------------

-- Chậm hơn: OR ngăn optimizer dùng index hiệu quả
-- SELECT * FROM nhankhau WHERE Ten = 'Nguyễn Văn An' OR CCCD = '030848872563';

-- Nhanh hơn: mỗi nhánh UNION dùng index riêng
SELECT MaNhanKhau, Ten, CCCD FROM nhankhau WHERE Ten   = 'Nguyễn Văn An'
UNION
SELECT MaNhanKhau, Ten, CCCD FROM nhankhau WHERE CCCD  = '030848872563';

-- =====================================================
-- 7.7 VIEWS TỐI ƯU (TÁI SỬ DỤNG QUERY PHỨC TẠP)
-- =====================================================

-- View danh sách nhân khẩu đầy đủ thông tin hộ khẩu
CREATE OR REPLACE VIEW vw_nhankhau_daydu AS
SELECT
    n.MaNhanKhau,
    n.Ten,
    n.NgaySinh,
    n.GioiTinh,
    n.QueQuan,
    n.DanToc,
    n.TonGiao,
    n.CCCD,
    n.NgheNghiep,
    h.MaHoKhau,
    h.TenChuHo,
    h.KhuVuc,
    h.DiaChiHK
FROM nhankhau n
JOIN hokhau h ON n.MaHoKhau = h.MaHoKhau;

-- View danh sách nhân khẩu có tiền án tiền sự
CREATE OR REPLACE VIEW vw_nhankhau_tienantiensu AS
SELECT
    n.MaNhanKhau,
    n.Ten,
    n.MaHoKhau,
    h.KhuVuc,
    t.MaTienAnTienSu,
    t.TenTienAnTienSu,
    t.NoiXetXu,
    t.NgayThucThi
FROM nhankhau n
JOIN hokhau h       ON n.MaHoKhau   = h.MaHoKhau
JOIN tienantiensu t ON n.MaNhanKhau = t.MaNhanKhau;

-- View danh sách người đang tạm trú
CREATE OR REPLACE VIEW vw_tamtru_daydu AS
SELECT
    tt.MaTamTru,
    tt.TenNoiTamTru,
    tt.DiaChi,
    tt.ThoiHan,
    n.MaNhanKhau,
    n.Ten,
    n.CCCD,
    n.MaHoKhau
FROM tamtru tt
JOIN nhankhau n ON tt.MaNhanKhau = n.MaNhanKhau;

-- View thống kê nhân khẩu theo khu vực
CREATE OR REPLACE VIEW vw_thongke_khuvuc AS
SELECT
    h.KhuVuc,
    COUNT(DISTINCT h.MaHoKhau)   AS SoHoKhau,
    COUNT(n.MaNhanKhau)           AS TongNhanKhau,
    SUM(n.GioiTinh = 'Nam')       AS SoNam,
    SUM(n.GioiTinh = 'Nữ')        AS SoNu
FROM hokhau h
LEFT JOIN nhankhau n ON h.MaHoKhau = n.MaHoKhau
GROUP BY h.KhuVuc;

-- View thống kê nghề nghiệp
CREATE OR REPLACE VIEW vw_thongke_nghenghiep AS
SELECT
    NgheNghiep,
    COUNT(*)                              AS SoNguoi,
    SUM(GioiTinh = 'Nam')                 AS SoNam,
    SUM(GioiTinh = 'Nữ')                  AS SoNu,
    ROUND(COUNT(*) * 100.0 /
          (SELECT COUNT(*) FROM nhankhau), 2) AS TyLePhanTram
FROM nhankhau
GROUP BY NgheNghiep
ORDER BY SoNguoi DESC;

-- =====================================================
-- 7.8 STORED PROCEDURE TỐI ƯU (THAY THẾ QUERY LẶP LẠI)
-- =====================================================

-- 7.8.1 Tìm kiếm nhân khẩu linh hoạt (tránh dynamic SQL không an toàn)
DROP PROCEDURE IF EXISTS sp_TimNhanKhau;

DELIMITER $$

CREATE PROCEDURE sp_TimNhanKhau(
    IN p_Ten        VARCHAR(50),
    IN p_KhuVuc     VARCHAR(50),
    IN p_NgheNghiep VARCHAR(100),
    IN p_GioiTinh   VARCHAR(10)
)
BEGIN
    SELECT
        n.MaNhanKhau, n.Ten, n.NgaySinh, n.GioiTinh,
        n.NgheNghiep, h.KhuVuc, h.DiaChiHK
    FROM nhankhau n
    JOIN hokhau h ON n.MaHoKhau = h.MaHoKhau
    WHERE (p_Ten        IS NULL OR n.Ten        LIKE CONCAT(p_Ten, '%'))
      AND (p_KhuVuc     IS NULL OR h.KhuVuc     = p_KhuVuc)
      AND (p_NgheNghiep IS NULL OR n.NgheNghiep = p_NgheNghiep)
      AND (p_GioiTinh   IS NULL OR n.GioiTinh   = p_GioiTinh);
END$$

DELIMITER ;

-- Ví dụ gọi: tìm nữ giáo viên tại Phường 3
CALL sp_TimNhanKhau(NULL, 'Phường 3', 'Giáo viên', 'Nữ');

-- 7.8.2 Báo cáo thống kê theo khu vực (kết quả được cache trong procedure)
DROP PROCEDURE IF EXISTS sp_BaoCaoKhuVuc;

DELIMITER $$

CREATE PROCEDURE sp_BaoCaoKhuVuc(IN p_KhuVuc VARCHAR(50))
BEGIN
    -- Tổng quan hộ khẩu
    SELECT
        h.KhuVuc,
        COUNT(DISTINCT h.MaHoKhau)   AS TongHoKhau,
        COUNT(n.MaNhanKhau)           AS TongNhanKhau,
        SUM(n.GioiTinh = 'Nam')       AS TongNam,
        SUM(n.GioiTinh = 'Nữ')        AS TongNu
    FROM hokhau h
    LEFT JOIN nhankhau n ON h.MaHoKhau = n.MaHoKhau
    WHERE h.KhuVuc = p_KhuVuc
    GROUP BY h.KhuVuc;

    -- Top 5 nghề nghiệp phổ biến
    SELECT n.NgheNghiep, COUNT(*) AS SoNguoi
    FROM nhankhau n
    JOIN hokhau h ON n.MaHoKhau = h.MaHoKhau
    WHERE h.KhuVuc = p_KhuVuc
    GROUP BY n.NgheNghiep
    ORDER BY SoNguoi DESC
    LIMIT 5;

    -- Số người đang tạm trú trong khu vực
    SELECT COUNT(*) AS SoTamTru
    FROM tamtru tt
    JOIN nhankhau n ON tt.MaNhanKhau = n.MaNhanKhau
    JOIN hokhau h   ON n.MaHoKhau   = h.MaHoKhau
    WHERE h.KhuVuc = p_KhuVuc;
END$$

DELIMITER ;

CALL sp_BaoCaoKhuVuc('Phường 3');

-- =====================================================
-- 7.9 PHÂN TÍCH & BẢO TRÌ INDEX
-- =====================================================

-- Xem tất cả index trên từng bảng
SHOW INDEX FROM hokhau;
SHOW INDEX FROM nhankhau;
SHOW INDEX FROM tamtru;
SHOW INDEX FROM tienantiensu;
SHOW INDEX FROM kethon;
SHOW INDEX FROM chungtu;

-- Cập nhật thống kê để optimizer có thông tin chính xác
ANALYZE TABLE hokhau;
ANALYZE TABLE nhankhau;
ANALYZE TABLE tamtru;
ANALYZE TABLE tienantiensu;
ANALYZE TABLE kethon;
ANALYZE TABLE chungtu;

-- Kiểm tra và tối ưu hóa bảng (chống phân mảnh sau DELETE/UPDATE nhiều)
OPTIMIZE TABLE hokhau;
OPTIMIZE TABLE nhankhau;
OPTIMIZE TABLE tamtru;
OPTIMIZE TABLE tienantiensu;
OPTIMIZE TABLE kethon;
OPTIMIZE TABLE chungtu;

-- =====================================================
-- 7.10 QUERY CỤ THỂ ĐÃ ĐƯỢC TỐI ƯU
-- Các truy vấn nghiệp vụ thường dùng, viết theo chuẩn tối ưu.
-- =====================================================

-- 7.10.1 Danh sách nhân khẩu chưa có nghề nghiệp ổn định
SELECT n.MaNhanKhau, n.Ten, n.NgaySinh, n.NgheNghiep, h.KhuVuc
FROM nhankhau n
JOIN hokhau h ON n.MaHoKhau = h.MaHoKhau
WHERE n.NgheNghiep IN ('Thất nghiệp', 'Sinh viên', 'Học sinh')
ORDER BY h.KhuVuc, n.Ten
LIMIT 50;

-- 7.10.2 Thống kê nhân khẩu theo dân tộc và giới tính
SELECT
    DanToc,
    GioiTinh,
    COUNT(*) AS SoNguoi
FROM nhankhau
GROUP BY DanToc, GioiTinh
ORDER BY DanToc, GioiTinh;

-- 7.10.3 Nhân khẩu có tiền án trong 5 năm gần nhất theo khu vực
SELECT
    h.KhuVuc,
    COUNT(DISTINCT t.MaNhanKhau) AS SoNguoiCoTienAn,
    GROUP_CONCAT(DISTINCT t.TenTienAnTienSu ORDER BY t.TenTienAnTienSu SEPARATOR ', ') AS LoaiVuAn
FROM tienantiensu t
JOIN nhankhau n ON t.MaNhanKhau = n.MaNhanKhau
JOIN hokhau h   ON n.MaHoKhau   = h.MaHoKhau
WHERE t.NgayThucThi >= DATE_SUB(CURDATE(), INTERVAL 5 YEAR)
GROUP BY h.KhuVuc
ORDER BY SoNguoiCoTienAn DESC;

-- 7.10.4 Người đang tạm trú dài hạn (>= 12 tháng)
SELECT
    n.MaNhanKhau, n.Ten, n.CCCD,
    tt.TenNoiTamTru, tt.ThoiHan,
    h.KhuVuc AS KhuVucHoKhauGoc
FROM tamtru tt
JOIN nhankhau n ON tt.MaNhanKhau = n.MaNhanKhau
JOIN hokhau h   ON n.MaHoKhau   = h.MaHoKhau
WHERE tt.ThoiHan IN ('12 tháng', '24 tháng')
ORDER BY tt.ThoiHan DESC, n.Ten;

-- 7.10.5 Phân bố độ tuổi nhân khẩu theo nhóm
SELECT
    CASE
        WHEN TIMESTAMPDIFF(YEAR, NgaySinh, CURDATE()) < 18  THEN 'Dưới 18'
        WHEN TIMESTAMPDIFF(YEAR, NgaySinh, CURDATE()) < 35  THEN '18 - 34'
        WHEN TIMESTAMPDIFF(YEAR, NgaySinh, CURDATE()) < 60  THEN '35 - 59'
        ELSE 'Từ 60 trở lên'
    END AS NhomTuoi,
    COUNT(*)                   AS SoNguoi,
    SUM(GioiTinh = 'Nam')      AS SoNam,
    SUM(GioiTinh = 'Nữ')       AS SoNu
FROM nhankhau
GROUP BY NhomTuoi
ORDER BY FIELD(NhomTuoi, 'Dưới 18', '18 - 34', '35 - 59', 'Từ 60 trở lên');

-- 7.10.6 Hộ khẩu không có nhân khẩu nào (dùng LEFT JOIN + IS NULL thay NOT IN)
SELECT h.MaHoKhau, h.TenChuHo, h.KhuVuc, h.NgayLap
FROM hokhau h
LEFT JOIN nhankhau n ON h.MaHoKhau = n.MaHoKhau
WHERE n.MaNhanKhau IS NULL
ORDER BY h.NgayLap DESC;

-- 7.10.7 Kết hôn theo năm và khu vực
SELECT
    YEAR(NgayDangKy) AS Nam,
    KhuVucDangKy,
    COUNT(*)         AS SoCap
FROM kethon
GROUP BY YEAR(NgayDangKy), KhuVucDangKy
ORDER BY Nam DESC, SoCap DESC;

-- 7.10.8 Khai tử theo năm và khu vực
SELECT
    YEAR(NgayMat)   AS Nam,
    KhuVucDangKy,
    COUNT(*)        AS SoNguoiMat
FROM chungtu
GROUP BY YEAR(NgayMat), KhuVucDangKy
ORDER BY Nam DESC, SoNguoiMat DESC;

-- =====================================================
-- 7.11 KIỂM TRA HIỆU NĂNG TỔNG THỂ
-- =====================================================

-- Xem kích thước từng bảng và số bản ghi ước tính
SELECT
    TABLE_NAME                                   AS TenBang,
    TABLE_ROWS                                   AS UocTinhBanGhi,
    ROUND(DATA_LENGTH  / 1024, 2)                AS DuLieu_KB,
    ROUND(INDEX_LENGTH / 1024, 2)                AS Index_KB,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024, 2) AS TongDungLuong_KB
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'project'
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC;

-- Xem các index đang có trên toàn bộ database
SELECT
    TABLE_NAME   AS TenBang,
    INDEX_NAME   AS TenIndex,
    COLUMN_NAME  AS TenCot,
    SEQ_IN_INDEX AS ThuTuCot,
    NON_UNIQUE   AS KhongDuy_Nhat,
    INDEX_TYPE   AS KieuIndex
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'project'
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;
