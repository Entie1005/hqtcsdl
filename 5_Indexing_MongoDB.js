// =====================================================
// 5_Indexing_MongoDB.js (BẢN CHUẨN HÓA THEO CAMELCASE)
// Hệ thống Quản lý Nhân Khẩu - MongoDB
// =====================================================

print("🧹 Đang dọn dẹp index cũ trên các collection (giữ lại _id)...");

function dropUserIndexes(colName) {
  const col = db.getCollection(colName);
  if (!col) return;
  const indexes = col.getIndexes().filter(i => i.name !== "_id_");
  for (const idx of indexes) {
    try { col.dropIndex(idx.name); } catch (e) {}
  }
  print(`  ✓ Đã xóa index cũ trên [${colName}]`);
}

["hoKhau", "ketHon", "chungTu", "canBo"].forEach(dropUserIndexes);


// =====================================================
// PHẦN 1 & 2 & 3: THIẾT LẬP CÁC CHỈ MỤC TỐI ƯU HÓA (INDEXING)
// =====================================================

print("\n📌 KHỞI TẠO SINGLE FIELD, COMPOUND & MULTIKEY INDEX");
print("=".repeat(50));

// Tra cứu nhanh theo mã hộ khẩu
db.hoKhau.createIndex({ maHoKhau: 1 }, { unique: true, name: "idx_hk_mahokhau" });

// Tìm kiếm hộ khẩu, nhân khẩu theo khu vực hành chính
db.hoKhau.createIndex({ khuVuc: 1 }, { name: "idx_hk_khuvuc" });

// Multikey Index: Tra cứu nhân khẩu theo CCCD nhúng sâu trong mảng
db.hoKhau.createIndex({ "nhanKhau.cccd": 1 }, { unique: true, name: "idx_nk_cccd" });

// Multikey Index: Tìm nhân khẩu theo mã nhân khẩu
db.hoKhau.createIndex({ "nhanKhau.maNhanKhau": 1 }, { unique: true, name: "idx_nk_manhankhau" });

// Thống kê dân số theo giới tính và khu vực (Compound Index - Quy tắc ESR)
db.hoKhau.createIndex({ khuVuc: 1, "nhanKhau.gioiTinh": 1 }, { name: "idx_hk_khuvuc_gioitinh" });

// Lọc độ tuổi lao động theo vùng (Compound Index)
db.hoKhau.createIndex({ khuVuc: 1, "nhanKhau.ngaySinh": 1 }, { name: "idx_hk_khuvuc_ngaysinh" });

// Tra cứu chéo giới tính và nghề nghiệp toàn hệ thống
db.hoKhau.createIndex({ "nhanKhau.gioiTinh": 1, "nhanKhau.ngheNghiep": 1 }, { name: "idx_nk_gioitinh_nghenghiep" });


// ── Index cho các bảng nghiệp vụ liên kết ─────────────────

db.ketHon.createIndex({ cccdChong: 1 }, { unique: true, name: "idx_kh_cccdchong" });
db.ketHon.createIndex({ cccdVo: 1 }, { unique: true, name: "idx_kh_cccdvo" });
db.ketHon.createIndex({ khuVucDangKy: 1, ngayDangKy: 1 }, { name: "idx_kh_khuvuc_ngaydangky" });

db.chungTu.createIndex({ cccd: 1 }, { unique: true, name: "idx_ct_cccd" });
db.chungTu.createIndex({ khuVucDangKy: 1, ngayMat: 1 }, { name: "idx_ct_khuvuc_ngaymat" });


// =====================================================
// PHẦN 4: TEXT INDEX (Tìm kiếm văn bản Tiếng Việt toàn văn)
// =====================================================

print("\n📌 PHẦN 4: TEXT INDEX");
print("=".repeat(50));

db.hoKhau.createIndex(
  {
    "tenChuHo": "text",
    "nhanKhau.ten": "text",
    "nhanKhau.ngheNghiep": "text"
  },
  {
    name: "idx_hokhau_text_search",
    weights: { "nhanKhau.ten": 10, "tenChuHo": 5, "nhanKhau.ngheNghiep": 1 },
    default_language: "none"
  }
);
print("  [IDX] Tạo xong Text Index hỗ trợ tìm kiếm tiếng Việt thông minh.");


// =====================================================
// PHẦN 5 & 6: PARTIAL & SPARSE INDEX
// =====================================================

print("\n📌 PHẦN 5 & 6: PARTIAL & SPARSE INDEX");
print("=".repeat(50));

// Partial Index: Chỉ index những nhân khẩu thuộc nhóm tuổi lao động (Ví dụ sinh từ 1966 - 2011)
db.hoKhau.createIndex(
  { "nhanKhau.ngheNghiep": 1, khuVuc: 1 },
  {
    partialFilterExpression: {
      "nhanKhau.ngaySinh": { $gte: new Date("1966-01-01"), $lte: new Date("2011-01-01") }
    },
    name: "idx_hk_partial_laodong"
  }
);

// Sparse Index: Chỉ lưu vết những nhân khẩu có biến động hoặc trạng thái đặc biệt
db.hoKhau.createIndex(
  { "nhanKhau.trangThaiDacBiet": 1 },
  { sparse: true, name: "idx_hk_sparse_trangthai" }
);
print("  [IDX] Khởi tạo Partial Index và Sparse Index hoàn tất.");


// =====================================================
// PHẦN 7: TTL INDEX (Time-To-Live - Tự động xóa dữ liệu hết hạn)
// =====================================================

print("\n📌 PHẦN 7: TTL INDEX");
print("=".repeat(50));

db.canbo_sessions.drop();
db.createCollection("canbo_sessions");
db.canbo_sessions.createIndex(
  { thoiGianTao: 1 },
  { expireAfterSeconds: 28800, name: "idx_ss_ttl_8h" }
);
print("  [IDX] Tạo bảng quản lý phiên canbo_sessions tự động hủy sau 8 giờ.");


// =====================================================
// PHẦN 9: ĐO LƯỜNG VÀ PHÂN TÍCH HIỆU NĂNG THỰC TẾ
// =====================================================

print("\n📌 PHẦN 9: ĐO LƯỜNG HIỆU NĂNG INDEX");
print("=".repeat(50));

function doHieuNangHoKhau(moTa, query) {
  const stats = db.hoKhau.find(query).explain("executionStats");
  const s = stats.executionStats;
  const stage = stats.queryPlanner.winningPlan.stage || stats.queryPlanner.winningPlan.inputStage?.stage;

  print(`\n  📊 Thử nghiệm: ${moTa}`);
  print(`     Stage vận hành:          ${stage}`);
  print(`     Số bản ghi phải duyệt:   ${s.totalDocsExamined}`);
  print(`     Số bản ghi trả về:       ${s.nReturned}`);
  print(`     Thời gian thực thi:      ${s.executionTimeMillis} ms`);
  if (stage === "COLLSCAN") {
    print("     ⚠️  COLLSCAN — Không dùng index!");
  } else {
    print("     ✅ IXSCAN — Đang tận dụng cấu trúc Index rất tốt.");
  }
}

// Chạy test thử nghiệm đo lường hiệu năng
doHieuNangHoKhau("Tìm kiếm Hộ khẩu chính xác theo mã", { maHoKhau: "HK00000001" });
doHieuNangHoKhau("Lọc danh sách theo địa bàn khu vực", { khuVuc: "Phường 3" });


// ── Thống kê bộ nhớ và dung lượng lưu trữ ─────────────────
print("\n  --- Dung lượng lưu trữ vật lý của hệ thống ---");
const hokhauStats = db.hoKhau.stats();
print(`  Tổng dung lượng Index chiếm dụng: ${(hokhauStats.totalIndexSize / 1024).toFixed(1)} KB`);
print(`  Dung lượng data gốc:               ${(hokhauStats.size / 1024).toFixed(1)} KB`);
print(`  Tổng số lượng Index đang chạy:     ${hokhauStats.nindexes}`);

print("\n=====================================================");
print("✅ HOÀN THÀNH 100% FILE SCRIPT INDEX MONGODB AN TOÀN!");
print("=====================================================");