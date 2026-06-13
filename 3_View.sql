-- =====================================================
-- 3_View.sql
-- Hệ thống Quản lý Nhân Khẩu
-- Gồm: 20 Views cho toàn bộ nghiệp vụ báo cáo
-- =====================================================

USE project;

-- =====================================================
-- NHÓM 1: NHÂN KHẨU & HỘ KHẨU
-- VIEW 01 - VIEW 06
-- =====================================================

-- ----------------------------------------------------
-- VIEW 01: Danh sách nhân khẩu đầy đủ thông tin
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_NhanKhauDayDu AS
SELECT
    nk.MaNhanKhau,
    nk.Ten,
    nk.NgaySinh,
    TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE())     AS Tuoi,
    nk.GioiTinh,
    nk.QueQuan,
    nk.TonGiao,
    nk.DanToc,
    nk.CCCD,
    nk.NgheNghiep,
    hk.MaHoKhau,
    hk.TenChuHo,
    hk.CCCDChuHo,
    hk.KhuVuc,
    hk.DiaChiHK,
    hk.NgayLap                                       AS NgayLapHoKhau
FROM nhankhau nk
LEFT JOIN hokhau hk ON nk.MaHoKhau = hk.MaHoKhau;

-- ----------------------------------------------------
-- VIEW 02: Thống kê số nhân khẩu theo từng hộ khẩu
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_ThongKeHoKhau AS
SELECT
    hk.MaHoKhau,
    hk.TenChuHo,
    hk.CCCDChuHo,
    hk.KhuVuc,
    hk.DiaChiHK,
    hk.NgayLap,
    COUNT(nk.MaNhanKhau)                                AS SoNhanKhau,
    SUM(nk.GioiTinh = 'Nam')                            AS SoNam,
    SUM(nk.GioiTinh = 'Nữ')                             AS SoNu,
    MIN(nk.NgaySinh)                                    AS NgaySinhNhaNhat,
    MAX(nk.NgaySinh)                                    AS NgaySinhTreNhat
FROM hokhau hk
LEFT JOIN nhankhau nk ON hk.MaHoKhau = nk.MaHoKhau
GROUP BY
    hk.MaHoKhau, hk.TenChuHo, hk.CCCDChuHo,
    hk.KhuVuc, hk.DiaChiHK, hk.NgayLap;

-- ----------------------------------------------------
-- VIEW 03: Thống kê dân số theo khu vực
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_DanSoTheoKhuVuc AS
SELECT
    hk.KhuVuc,
    COUNT(DISTINCT hk.MaHoKhau)                                         AS SoHoKhau,
    COUNT(nk.MaNhanKhau)                                                 AS TongNhanKhau,
    SUM(nk.GioiTinh = 'Nam')                                            AS SoNam,
    SUM(nk.GioiTinh = 'Nữ')                                             AS SoNu,
    SUM(TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE()) < 15)               AS SoTreEm,
    SUM(TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE()) BETWEEN 15 AND 60)  AS SoLaoDong,
    SUM(TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE()) > 60)               AS SoNguoiGia,
    ROUND(AVG(TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE())), 1)          AS TuoiTrungBinh
FROM hokhau hk
LEFT JOIN nhankhau nk ON hk.MaHoKhau = nk.MaHoKhau
GROUP BY hk.KhuVuc;

-- ----------------------------------------------------
-- VIEW 04: Nhân khẩu trong độ tuổi lao động (15 - 60)
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_NhanKhauLaoDong AS
SELECT
    nk.MaNhanKhau,
    nk.Ten,
    nk.NgaySinh,
    TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE())     AS Tuoi,
    nk.GioiTinh,
    nk.NgheNghiep,
    nk.DanToc,
    nk.QueQuan,
    hk.KhuVuc,
    hk.DiaChiHK
FROM nhankhau nk
LEFT JOIN hokhau hk ON nk.MaHoKhau = hk.MaHoKhau
WHERE TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE()) BETWEEN 15 AND 60;

-- ----------------------------------------------------
-- VIEW 05: Trẻ em dưới 15 tuổi
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_TreEm AS
SELECT
    nk.MaNhanKhau,
    nk.Ten,
    nk.NgaySinh,
    TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE())     AS Tuoi,
    nk.GioiTinh,
    nk.DanToc,
    hk.TenChuHo                                      AS TenChuHo,
    hk.KhuVuc,
    hk.DiaChiHK
FROM nhankhau nk
LEFT JOIN hokhau hk ON nk.MaHoKhau = hk.MaHoKhau
WHERE TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE()) < 15;

-- ----------------------------------------------------
-- VIEW 06: Người cao tuổi (trên 60 tuổi)
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_NguoiCaoTuoi AS
SELECT
    nk.MaNhanKhau,
    nk.Ten,
    nk.NgaySinh,
    TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE())     AS Tuoi,
    nk.GioiTinh,
    nk.TonGiao,
    nk.DanToc,
    nk.NgheNghiep,
    hk.KhuVuc,
    hk.DiaChiHK,
    hk.TenChuHo
FROM nhankhau nk
LEFT JOIN hokhau hk ON nk.MaHoKhau = hk.MaHoKhau
WHERE TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE()) > 60;


-- =====================================================
-- NHÓM 2: TIỀN ÁN TIỀN SỰ
-- VIEW 07 - VIEW 09
-- =====================================================

-- ----------------------------------------------------
-- VIEW 07: Danh sách nhân khẩu có tiền án tiền sự
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_NhanKhauTienAnTienSu AS
SELECT
    nk.MaNhanKhau,
    nk.Ten,
    nk.NgaySinh,
    nk.GioiTinh,
    nk.CCCD,
    hk.KhuVuc,
    hk.DiaChiHK,
    ts.MaTienAnTienSu,
    ts.TenTienAnTienSu                               AS LoaiViPham,
    ts.NoiXetXu,
    ts.NgayThucThi,
    TIMESTAMPDIFF(YEAR, ts.NgayThucThi, CURDATE())   AS SoNamDaChapHanh
FROM nhankhau nk
JOIN tienantiensu ts      ON nk.MaNhanKhau = ts.MaNhanKhau
LEFT JOIN hokhau hk       ON nk.MaHoKhau   = hk.MaHoKhau;

-- ----------------------------------------------------
-- VIEW 08: Thống kê tiền án tiền sự theo khu vực
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_ThongKeTienAnTheoKhuVuc AS
SELECT
    hk.KhuVuc,
    COUNT(ts.MaTienAnTienSu)                         AS TongViPham,
    COUNT(DISTINCT ts.MaNhanKhau)                    AS SoNguoiViPham,
    COUNT(DISTINCT ts.TenTienAnTienSu)               AS SoLoaiViPham
FROM tienantiensu ts
JOIN nhankhau nk    ON ts.MaNhanKhau = nk.MaNhanKhau
LEFT JOIN hokhau hk ON nk.MaHoKhau  = hk.MaHoKhau
GROUP BY hk.KhuVuc;

-- ----------------------------------------------------
-- VIEW 09: Thống kê tiền án tiền sự theo loại vi phạm
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_ThongKeTienAnTheoLoai AS
SELECT
    TenTienAnTienSu                                  AS LoaiViPham,
    NoiXetXu,
    COUNT(*)                                         AS SoTruongHop,
    MIN(NgayThucThi)                                 AS LanDauGhiNhan,
    MAX(NgayThucThi)                                 AS LanCuoiGhiNhan
FROM tienantiensu
GROUP BY TenTienAnTienSu, NoiXetXu
ORDER BY SoTruongHop DESC;


-- =====================================================
-- NHÓM 3: TẠM TRÚ
-- VIEW 10 - VIEW 12
-- =====================================================

-- ----------------------------------------------------
-- VIEW 10: Danh sách người đang tạm trú (đầy đủ)
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_DanhSachTamTru AS
SELECT
    tt.MaTamTru,
    tt.TenNoiTamTru,
    tt.DiaChi                                        AS DiaChiTamTru,
    tt.SoDienThoai,
    tt.ThoiHan,
    nk.MaNhanKhau,
    nk.Ten,
    nk.NgaySinh,
    TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE())     AS Tuoi,
    nk.GioiTinh,
    nk.CCCD,
    nk.QueQuan,
    hk.KhuVuc                                        AS KhuVucHoKhau,
    hk.DiaChiHK                                      AS DiaChiHoKhau
FROM tamtru tt
JOIN nhankhau nk       ON tt.MaNhanKhau = nk.MaNhanKhau
LEFT JOIN hokhau hk    ON nk.MaHoKhau   = hk.MaHoKhau;

-- ----------------------------------------------------
-- VIEW 11: Thống kê tạm trú theo khu vực hộ khẩu
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_ThongKeTamTruTheoKhuVuc AS
SELECT
    hk.KhuVuc,
    COUNT(tt.MaTamTru)                               AS SoNguoiTamTru,
    COUNT(DISTINCT tt.TenNoiTamTru)                  AS SoNhaTro,
    SUM(nk.GioiTinh = 'Nam')                         AS SoNam,
    SUM(nk.GioiTinh = 'Nữ')                          AS SoNu
FROM tamtru tt
JOIN nhankhau nk    ON tt.MaNhanKhau = nk.MaNhanKhau
LEFT JOIN hokhau hk ON nk.MaHoKhau  = hk.MaHoKhau
GROUP BY hk.KhuVuc;

-- ----------------------------------------------------
-- VIEW 12: Nhân khẩu vừa có tạm trú vừa có tiền án
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_TamTruCoTienAn AS
SELECT DISTINCT
    nk.MaNhanKhau,
    nk.Ten,
    nk.CCCD,
    nk.GioiTinh,
    hk.KhuVuc,
    tt.TenNoiTamTru,
    tt.DiaChi                                        AS DiaChiTamTru,
    ts.TenTienAnTienSu                               AS LoaiViPham,
    ts.NgayThucThi
FROM nhankhau nk
JOIN tamtru tt        ON nk.MaNhanKhau = tt.MaNhanKhau
JOIN tienantiensu ts  ON nk.MaNhanKhau = ts.MaNhanKhau
LEFT JOIN hokhau hk   ON nk.MaHoKhau  = hk.MaHoKhau;


-- =====================================================
-- NHÓM 4: KẾT HÔN
-- VIEW 13 - VIEW 15
-- =====================================================

-- ----------------------------------------------------
-- VIEW 13: Danh sách hồ sơ kết hôn đầy đủ
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_DanhSachKetHon AS
SELECT
    MaKetHon,
    TenChong,
    NgaySinhChong,
    TIMESTAMPDIFF(YEAR, NgaySinhChong, CURDATE())    AS TuoiChong,
    DanTocChong,
    QuocTichChong,
    ThuongTamTruChong,
    CCCDChong,
    TenVo,
    NgaySinhVo,
    TIMESTAMPDIFF(YEAR, NgaySinhVo, CURDATE())       AS TuoiVo,
    DanTocVo,
    QuocTichVo,
    ThuongTamTruVo,
    CCCDVo,
    KhuVucDangKy,
    NgayDangKy,
    TIMESTAMPDIFF(YEAR, NgayDangKy, CURDATE())       AS SoNamKetHon
FROM kethon;

-- ----------------------------------------------------
-- VIEW 14: Thống kê kết hôn theo khu vực
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_ThongKeKetHonTheoKhuVuc AS
SELECT
    KhuVucDangKy,
    COUNT(*)                                         AS SoCapKetHon,
    MIN(NgayDangKy)                                  AS NgayDangKySomNhat,
    MAX(NgayDangKy)                                  AS NgayDangKyMuonNhat,
    ROUND(AVG(TIMESTAMPDIFF(YEAR, NgaySinhChong, NgayDangKy)), 1)   AS TuoiChongTB,
    ROUND(AVG(TIMESTAMPDIFF(YEAR, NgaySinhVo,   NgayDangKy)), 1)    AS TuoiVoTB
FROM kethon
GROUP BY KhuVucDangKy;

-- ----------------------------------------------------
-- VIEW 15: Thống kê kết hôn theo từng năm
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_ThongKeKetHonTheoNam AS
SELECT
    YEAR(NgayDangKy)                                 AS Nam,
    COUNT(*)                                         AS SoCapKetHon,
    COUNT(DISTINCT KhuVucDangKy)                     AS SoKhuVucCoKetHon
FROM kethon
GROUP BY YEAR(NgayDangKy)
ORDER BY Nam DESC;


-- =====================================================
-- NHÓM 5: CHỨNG TỪ KHAI TỬ
-- VIEW 16 - VIEW 18
-- =====================================================

-- ----------------------------------------------------
-- VIEW 16: Danh sách chứng từ khai tử đầy đủ
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_DanhSachKhaiTu AS
SELECT
    MaChungTu,
    TenNguoiKhai,
    ThuongTamTru                                     AS DiaChiNguoiKhai,
    QuanHeVoiNguoiMat,
    TenNguoiMat,
    NgaySinh,
    TIMESTAMPDIFF(YEAR, NgaySinh, NgayMat)           AS TuoiKhiMat,
    DanToc,
    QuocTich,
    CCCD,
    NgayMat,
    GioMat,
    KhuVucDangKy,
    NgayDangKy,
    DATEDIFF(NgayDangKy, NgayMat)                    AS SoNgayTuMatDenKhaiTu
FROM chungtu;

-- ----------------------------------------------------
-- VIEW 17: Thống kê tử vong theo khu vực
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_ThongKeTuVongTheoKhuVuc AS
SELECT
    KhuVucDangKy,
    COUNT(*)                                         AS TongSoNguoiMat,
    ROUND(AVG(TIMESTAMPDIFF(YEAR, NgaySinh, NgayMat)), 1)   AS TuoiTrungBinhKhiMat,
    MIN(TIMESTAMPDIFF(YEAR, NgaySinh, NgayMat))      AS TuoiMatNhoNhat,
    MAX(TIMESTAMPDIFF(YEAR, NgaySinh, NgayMat))      AS TuoiMatLonNhat
FROM chungtu
GROUP BY KhuVucDangKy;

-- ----------------------------------------------------
-- VIEW 18: Thống kê tử vong theo năm
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_ThongKeTuVongTheoNam AS
SELECT
    YEAR(NgayMat)                                    AS Nam,
    COUNT(*)                                         AS SoNguoiMat,
    COUNT(DISTINCT KhuVucDangKy)                     AS SoKhuVucCoNguoiMat,
    ROUND(AVG(TIMESTAMPDIFF(YEAR, NgaySinh, NgayMat)), 1)   AS TuoiTrungBinh
FROM chungtu
GROUP BY YEAR(NgayMat)
ORDER BY Nam DESC;


-- =====================================================
-- NHÓM 6: BÁO CÁO TỔNG HỢP
-- VIEW 19 - VIEW 20
-- =====================================================

-- ----------------------------------------------------
-- VIEW 19: Tổng hợp biến động dân số theo khu vực
--          (dân số hiện tại + số đám tang + số kết hôn)
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_BienDongDanSoTheoKhuVuc AS
SELECT
    ds.KhuVuc,
    ds.SoHoKhau,
    ds.TongNhanKhau,
    ds.SoNam,
    ds.SoNu,
    ds.SoTreEm,
    ds.SoLaoDong,
    ds.SoNguoiGia,
    ds.TuoiTrungBinh,
    COALESCE(kh.SoCapKetHon,    0)                   AS SoCapKetHon,
    COALESCE(tv.TongSoNguoiMat, 0)                   AS SoNguoiMat,
    COALESCE(ta.SoNguoiViPham,  0)                   AS SoNguoiCoTienAn,
    COALESCE(tt.SoNguoiTamTru,  0)                   AS SoNguoiTamTru
FROM vw_DanSoTheoKhuVuc          ds
LEFT JOIN vw_ThongKeKetHonTheoKhuVuc    kh ON ds.KhuVuc = kh.KhuVucDangKy
LEFT JOIN vw_ThongKeTuVongTheoKhuVuc    tv ON ds.KhuVuc = tv.KhuVucDangKy
LEFT JOIN vw_ThongKeTienAnTheoKhuVuc    ta ON ds.KhuVuc = ta.KhuVuc
LEFT JOIN vw_ThongKeTamTruTheoKhuVuc    tt ON ds.KhuVuc = tt.KhuVuc;

-- ----------------------------------------------------
-- VIEW 20: Bảng tra cứu nhân khẩu toàn diện
--          (ghép tất cả thông tin phụ: tạm trú, tiền án)
-- ----------------------------------------------------
CREATE OR REPLACE VIEW vw_TraCuuToanDien AS
SELECT
    nk.MaNhanKhau,
    nk.Ten,
    nk.NgaySinh,
    TIMESTAMPDIFF(YEAR, nk.NgaySinh, CURDATE())     AS Tuoi,
    nk.GioiTinh,
    nk.CCCD,
    nk.QueQuan,
    nk.TonGiao,
    nk.DanToc,
    nk.NgheNghiep,
    hk.MaHoKhau,
    hk.TenChuHo,
    hk.KhuVuc,
    hk.DiaChiHK,
    -- Tạm trú
    CASE WHEN EXISTS (SELECT 1 FROM tamtru       WHERE MaNhanKhau = nk.MaNhanKhau)
         THEN 'Có' ELSE 'Không' END                  AS CoTamTru,
    -- Tiền án tiền sự
    CASE WHEN EXISTS (SELECT 1 FROM tienantiensu WHERE MaNhanKhau = nk.MaNhanKhau)
         THEN 'Có' ELSE 'Không' END                  AS CoTienAnTienSu,
    -- Số lần tiền án
    (SELECT COUNT(*) FROM tienantiensu WHERE MaNhanKhau = nk.MaNhanKhau) AS SoLanViPham
FROM nhankhau nk
LEFT JOIN hokhau hk ON nk.MaHoKhau = hk.MaHoKhau;


-- =====================================================
-- HƯỚNG DẪN SỬ DỤNG
-- =====================================================
/*
== NHÓM 1: NHÂN KHẨU & HỘ KHẨU ==
SELECT * FROM vw_NhanKhauDayDu;
SELECT * FROM vw_NhanKhauDayDu     WHERE KhuVuc = 'Phường 1';
SELECT * FROM vw_ThongKeHoKhau     ORDER BY SoNhanKhau DESC;
SELECT * FROM vw_DanSoTheoKhuVuc;
SELECT * FROM vw_NhanKhauLaoDong   WHERE KhuVuc = 'Phường 2';
SELECT * FROM vw_TreEm;
SELECT * FROM vw_NguoiCaoTuoi      ORDER BY Tuoi DESC;

== NHÓM 2: TIỀN ÁN TIỀN SỰ ==
SELECT * FROM vw_NhanKhauTienAnTienSu;
SELECT * FROM vw_NhanKhauTienAnTienSu  WHERE KhuVuc = 'Phường 1';
SELECT * FROM vw_ThongKeTienAnTheoKhuVuc;
SELECT * FROM vw_ThongKeTienAnTheoLoai;

== NHÓM 3: TẠM TRÚ ==
SELECT * FROM vw_DanhSachTamTru;
SELECT * FROM vw_DanhSachTamTru        WHERE KhuVucHoKhau = 'Phường 3';
SELECT * FROM vw_ThongKeTamTruTheoKhuVuc;
SELECT * FROM vw_TamTruCoTienAn;

== NHÓM 4: KẾT HÔN ==
SELECT * FROM vw_DanhSachKetHon        ORDER BY NgayDangKy DESC;
SELECT * FROM vw_ThongKeKetHonTheoKhuVuc;
SELECT * FROM vw_ThongKeKetHonTheoNam;

== NHÓM 5: KHAI TỬ ==
SELECT * FROM vw_DanhSachKhaiTu        ORDER BY NgayMat DESC;
SELECT * FROM vw_ThongKeTuVongTheoKhuVuc;
SELECT * FROM vw_ThongKeTuVongTheoNam;

== NHÓM 6: TỔNG HỢP ==
SELECT * FROM vw_BienDongDanSoTheoKhuVuc;
SELECT * FROM vw_TraCuuToanDien         WHERE Ten LIKE '%Nguyễn%';
SELECT * FROM vw_TraCuuToanDien         WHERE CoTienAnTienSu = 'Có';
SELECT * FROM vw_TraCuuToanDien         WHERE CoTamTru = 'Có' AND CoTienAnTienSu = 'Có';
*/
