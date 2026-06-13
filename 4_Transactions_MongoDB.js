// =====================================================
// 4_Transactions_MongoDB.js (BẢN VÁ LỖI SESSION MONGOSH)
// =====================================================

// ── COLLECTION LOG GIAO DỊCH ─────────────────────────────────────
db.transaction_log.drop();
db.createCollection("transaction_log", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["tenGiaoDich", "trangThai", "thoiGian"],
      properties: {
        tenGiaoDich: { bsonType: "string" },
        trangThai:   { enum: ["COMMIT", "ABORT", "ERROR"] },
        ghiChu:      { bsonType: "string" },
        thoiGian:    { bsonType: "date" },
        duLieuLienQuan: { bsonType: "object" }
      }
    }
  }
});

db.transaction_log.createIndex({ thoiGian: -1 });


// ── HÀM TIỆN ÍCH ─────────────────────────────────────────────────
function ghiLog(tenGD, trangThai, ghiChu, duLieu = {}) {
  try {
    db.transaction_log.insertOne({
      tenGiaoDich:    tenGD,
      trangThai:      trangThai,
      ghiChu:         ghiChu,
      thoiGian:       new Date(),
      duLieuLienQuan: duLieu
    });
  } catch(e) {}
}

function tinhTuoi(ngaySinh) {
  if (!ngaySinh) return 0;
  const ms = new Date() - new Date(ngaySinh);
  return Math.floor(ms / 31557600000);
}

function withRetry(fn, maxRetries = 3) {
  let attempt = 0;
  while (attempt < maxRetries) {
    try {
      return fn();
    } catch (e) {
      if (e && (e.hasErrorLabel?.("TransientTransactionError") || e.codeName === "WriteConflict")) {
        attempt++;
        print(`[RETRY ${attempt}/${maxRetries}] ${e.message}`);
        if (attempt === maxRetries) throw e;
        sleep(100 * attempt);
      } else {
        throw e;
      }
    }
  }
}


// ── KỊCH BẢN 1: ĐĂNG KÝ HỘ KHẨU MỚI ──────────────────────────────
function kb1_DangKyHoKhauMoi(thongTinHK, danhSachNK = []) {
  const session = db.getMongo().startSession();
  try {
    withRetry(() => {
      session.startTransaction({
        readConcern:  { level: "majority" },
        writeConcern: { w: "majority", j: true }
      });

      const col = session.getDatabase("nhanKhauDB").hoKhau;

      // Sửa lỗi truyền session trực tiếp trong mongosh
      const hkTonTai = col.findOne({ maHoKhau: thongTinHK.maHoKhau }, null, { session: session });
      if (hkTonTai) {
        session.abortTransaction();
        throw new Error(`Mã hộ khẩu "${thongTinHK.maHoKhau}" đã tồn tại.`);
      }

      const nhanKhauNhung = danhSachNK.map(nk => ({
        ...nk,
        tienAnTienSu: [],
        tamTru: [],
        version: 1,
        createdAt: new Date()
      }));

      col.insertOne({
        ...thongTinHK,
        nhanKhau: nhanKhauNhung,
        createdAt: new Date()
      }, { session: session });

      session.commitTransaction();

      ghiLog("DangKyHoKhauMoi", "COMMIT", `Tạo hộ khẩu ${thongTinHK.maHoKhau} thành công`);
      print(`✅ KB1 OK: Đã lập hộ khẩu "${thongTinHK.maHoKhau}" thành công.`);
    });
  } catch (e) {
    ghiLog("DangKyHoKhauMoi", "ABORT", e.message);
    print(`❌ KB1 ABORT: ${e.message}`);
  } finally {
    session.endSession();
  }
}


// ── KỊCH BẢN 2: CHUYỂN HỘ KHẨU ────────────────────────────────────
function kb2_ChuyenHoKhau(maNhanKhau, maHoKhauMoi) {
  const session = db.getMongo().startSession();
  try {
    withRetry(() => {
      session.startTransaction({
        readConcern:  { level: "snapshot" },
        writeConcern: { w: "majority", j: true }
      });

      const col = session.getDatabase("nhanKhauDB").hoKhau;

      const hkCu = col.findOne({ "nhanKhau.maNhanKhau": maNhanKhau }, null, { session: session });
      if (!hkCu) {
        session.abortTransaction();
        throw new Error(`Nhân khẩu "${maNhanKhau}" không tồn tại.`);
      }

      if (hkCu.maHoKhau === maHoKhauMoi) {
        session.abortTransaction();
        throw new Error("Nhân khẩu đã thuộc hộ khẩu này.");
      }

      const doiTuongNK = hkCu.nhanKhau.find(n => n.maNhanKhau === maNhanKhau);
      doiTuongNK.tamTru = [];
      doiTuongNK.updatedAt = new Date();

      col.updateOne({ maHoKhau: hkCu.maHoKhau }, { $pull: { nhanKhau: { maNhanKhau: maNhanKhau } } }, { session: session });
      
      const updateDest = col.updateOne({ maHoKhau: maHoKhauMoi }, { $push: { nhanKhau: doiTuongNK } }, { session: session });
      if (updateDest.matchedCount === 0) {
        session.abortTransaction();
        throw new Error(`Hộ khẩu đích "${maHoKhauMoi}" không tồn tại.`);
      }

      session.commitTransaction();
      ghiLog("ChuyenHoKhau", "COMMIT", `NK ${maNhanKhau}: ${hkCu.maHoKhau} -> ${maHoKhauMoi}`);
      print(`✅ KB2 OK: Đã chuyển NK "${maNhanKhau}" thành công.`);
    });
  } catch (e) {
    ghiLog("ChuyenHoKhau", "ABORT", e.message);
    print(`❌ KB2 ABORT: ${e.message}`);
  } finally {
    session.endSession();
  }
}


// ── KỊCH BẢN 3: ĐĂNG KÝ KẾT HÔN ──────────────────────────────────
function kb3_DangKyKetHon(hoSoKetHon) {
  const session = db.getMongo().startSession();
  try {
    withRetry(() => {
      session.startTransaction({
        readConcern:  { level: "snapshot" },
        writeConcern: { w: "majority", j: true }
      });

      const dbInstance = session.getDatabase("nhanKhauDB");
      if (hoSoKetHon.cccdChong === hoSoKetHon.cccdVo) {
        session.abortTransaction();
        throw new Error("CCCD chồng và vợ trùng nhau.");
      }

      const trungChong = dbInstance.ketHon.findOne({ $or: [{ cccdChong: hoSoKetHon.cccdChong }, { cccdVo: hoSoKetHon.cccdChong }] }, null, { session: session });
      if (trungChong) {
        session.abortTransaction();
        throw new Error(`CCCD "${hoSoKetHon.cccdChong}" đã kết hôn.`);
      }

      const thongTinChong = dbInstance.hoKhau.findOne({ "nhanKhau.cccd": hoSoKetHon.cccdChong }, null, { session: session });
      const thongTinVo    = dbInstance.hoKhau.findOne({ "nhanKhau.cccd": hoSoKetHon.cccdVo }, null, { session: session });

      if (!thongTinChong || !thongTinVo) {
        session.abortTransaction();
        throw new Error("Không tìm thấy thông tin nhân khẩu trên hệ thống.");
      }

      dbInstance.ketHon.insertOne({ ...hoSoKetHon, createdAt: new Date() }, { session: session });
      session.commitTransaction();

      ghiLog("DangKyKetHon", "COMMIT", `Mã KH: ${hoSoKetHon.maKetHon}`);
      print(`✅ KB3 OK: Đã phê duyệt kết hôn mã "${hoSoKetHon.maKetHon}".`);
    });
  } catch (e) {
    ghiLog("DangKyKetHon", "ABORT", e.message);
    print(`❌ KB3 ABORT: ${e.message}`);
  } finally {
    session.endSession();
  }
}


// ── KỊCH BẢN 4: KHAI TỬ ──────────────────────────────────────────
function kb4_KhaiTu(chungTu, maNhanKhau) {
  const session = db.getMongo().startSession();
  try {
    withRetry(() => {
      session.startTransaction({
        readConcern:  { level: "majority" },
        writeConcern: { w: "majority", j: true }
      });

      const dbInstance = session.getDatabase("nhanKhauDB");
      const daKhaiTu = dbInstance.chungTu.findOne({ cccd: chungTu.cccd }, null, { session: session });
      if (daKhaiTu) {
        session.abortTransaction();
        throw new Error("Hồ sơ đã được khai tử trước đó.");
      }

      dbInstance.chungTu.insertOne({ ...chungTu, createdAt: new Date() }, { session: session });

      const bghiHộ = dbInstance.hoKhau.findOne({ "nhanKhau.maNhanKhau": maNhanKhau }, null, { session: session });
      if (bghiHộ) {
        dbInstance.hoKhau.updateOne(
          { maHoKhau: bghiHộ.maHoKhau, "nhanKhau.maNhanKhau": maNhanKhau },
          {
            $set: {
              "nhanKhau.$.trangThaiDacBiet": "DA_KHAI_TU",
              "nhanKhau.$.ngayKhaiTu": new Date(chungTu.ngayMat),
              "nhanKhau.$.tamTru": [],
              "nhanKhau.$.tienAnTienSu": [],
              "nhanKhau.$.updatedAt": new Date()
            }
          },
          { session: session }
        );
      }

      session.commitTransaction();
      ghiLog("KhaiTu", "COMMIT", `Khai tử NK: ${maNhanKhau}`);
      print(`✅ KB4 OK: Đã hoàn tất thủ tục chứng tử cho NK "${maNhanKhau}".`);
    });
  } catch (e) {
    ghiLog("KhaiTu", "ABORT", e.message);
    print(`❌ KB4 ABORT: ${e.message}`);
  } finally {
    session.endSession();
  }
}


// ── KỊCH BẢN 5: ĐĂNG KÝ TẠM TRÚ ─────────────────────────────────
function kb5_DangKyTamTru(maNhanKhau, thongTinTamTru) {
  const session = db.getMongo().startSession();
  try {
    withRetry(() => {
      session.startTransaction({
        readConcern:  { level: "snapshot" },
        writeConcern: { w: "majority" }
      });

      const col = session.getDatabase("nhanKhauDB").hoKhau;
      const hoKhauDoc = col.findOne({ "nhanKhau.maNhanKhau": maNhanKhau }, null, { session: session });
      if (!hoKhauDoc) {
        session.abortTransaction();
        throw new Error(`Không tìm thấy nhân khẩu "${maNhanKhau}".`);
      }

      const nkDoiTuong = hoKhauDoc.nhanKhau.find(n => n.maNhanKhau === maNhanKhau);
      const daCoTamTru = (nkDoiTuong.tamTru || []).length > 0;

      if (daCoTamTru) {
        col.updateOne(
          { maHoKhau: hoKhauDoc.maHoKhau, "nhanKhau.maNhanKhau": maNhanKhau },
          {
            $set: {
              "nhanKhau.$.tamTru.0": { ...thongTinTamTru, capNhatLuc: new Date() },
              "nhanKhau.$.updatedAt": new Date()
            }
          },
          { session: session }
        );
      } else {
        col.updateOne(
          { maHoKhau: hoKhauDoc.maHoKhau, "nhanKhau.maNhanKhau": maNhanKhau },
          {
            $push: { "nhanKhau.$.tamTru": { ...thongTinTamTru, dangKyLuc: new Date() } },
            $set: { "nhanKhau.$.updatedAt": new Date() }
          },
          { session: session }
        );
      }

      session.commitTransaction();
      const hanhDong = daCoTamTru ? "CẬP NHẬT" : "TẠO MỚI";
      ghiLog("DangKyTamTru", "COMMIT", `${hanhDong} tạm trú cho NK ${maNhanKhau}`);
      print(`✅ KB5 OK: Đã ${hanhDong} thông tin tạm trú cho NK "${maNhanKhau}".`);
    });
  } catch (e) {
    ghiLog("DangKyTamTru", "ABORT", e.message);
    print(`❌ KB5 ABORT: ${e.message}`);
  } finally {
    session.endSession();
  }
}


// ── KỊCH BẢN 6: THÊM TIỀN ÁN ────────────────────────────────────
function kb6_ThemTienAn(maNhanKhau, tienAnMoi) {
  const session = db.getMongo().startSession();
  try {
    withRetry(() => {
      session.startTransaction({
        readConcern:  { level: "snapshot" },
        writeConcern: { w: "majority", j: true }
      });

      const col = session.getDatabase("nhanKhauDB").hoKhau;
      const trung = col.findOne({
        "nhanKhau.maNhanKhau": maNhanKhau,
        "nhanKhau.tienAnTienSu": {
          $elemMatch: { loaiViPham:  tienAnMoi.loaiViPham, ngayThucThi: tienAnMoi.ngayThucThi }
        }
      }, null, { session: session });

      if (trung) {
        session.abortTransaction();
        throw new Error("Hồ sơ tiền án này đã tồn tại.");
      }

      col.updateOne(
        { "nhanKhau.maNhanKhau": maNhanKhau },
        {
          $push: { "nhanKhau.$.tienAnTienSu": { ...tienAnMoi, ghiNhanLuc: new Date() } },
          $set: { "nhanKhau.$.updatedAt": new Date() }
        },
        { session: session }
      );

      session.commitTransaction();
      ghiLog("ThemTienAn", "COMMIT", `Thêm tiền án cho NK: ${maNhanKhau}`);
      print(`✅ KB6 OK: Ghi nhận tiền án tiền sự thành công.`);
    });
  } catch (e) {
    ghiLog("ThemTienAn", "ABORT", e.message);
    print(`❌ KB6 ABORT: ${e.message}`);
  } finally {
    session.endSession();
  }
}


// ── KỊCH BẢN 7: XÓA NHÂN KHẨU (ARCHIVE) ──────────────────────────
function kb7_XoaNhanKhau(maNhanKhau, lyDo) {
  const session = db.getMongo().startSession();
  try {
    withRetry(() => {
      session.startTransaction({
        readConcern:  { level: "majority" },
        writeConcern: { w: "majority", j: true }
      });

      const dbInstance = session.getDatabase("nhanKhauDB");
      const bghiHộ = dbInstance.hoKhau.findOne({ "nhanKhau.maNhanKhau": maNhanKhau }, null, { session: session });
      if (!bghiHộ) {
        session.abortTransaction();
        throw new Error(`Không tìm thấy nhân khẩu để xóa.`);
      }

      const thongTinNK = bghiHộ.nhanKhau.find(n => n.maNhanKhau === maNhanKhau);

      dbInstance.nhanKhau_archive.insertOne({
        ...thongTinNK,
        maHoKhauGoc: bghiHộ.maHoKhau,
        archivedAt:  new Date(),
        lyDoXoa:     lyDo
      }, { session: session });

      dbInstance.hoKhau.updateOne({ maHoKhau: bghiHộ.maHoKhau }, { $pull: { nhanKhau: { maNhanKhau: maNhanKhau } } }, { session: session });

      session.commitTransaction();
      ghiLog("XoaNhanKhau", "COMMIT", `Xóa NK: ${maNhanKhau}`);
      print(`✅ KB7 OK: Đã lưu archive và loại bỏ NK khỏi hệ thống.`);
    });
  } catch (e) {
    ghiLog("XoaNhanKhau", "ABORT", e.message);
    print(`❌ KB7 ABORT: ${e.message}`);
  } finally {
    session.endSession();
  }
}


// ── KỊCH BẢN 8: CẬP NHẬT HÀNG LOẠT ──────────────────────────────
function kb8_CapNhatHangLoat(khuVuc, ngheNghiepCu, ngheNghiepMoi) {
  const session = db.getMongo().startSession();
  try {
    withRetry(() => {
      session.startTransaction({
        readConcern:  { level: "majority" },
        writeConcern: { w: "majority" }
      });

      const col = session.getDatabase("nhanKhauDB").hoKhau;
      col.updateMany(
        { khuVuc: khuVuc, "nhanKhau.ngheNghiep": ngheNghiepCu },
        { $set: { "nhanKhau.$[elem].ngheNghiep": ngheNghiepMoi, "nhanKhau.$[elem].updatedAt": new Date() } },
        { arrayFilters: [{ "elem.ngheNghiep": ngheNghiepCu }], session: session }
      );

      session.commitTransaction();
      ghiLog("CapNhatHangLoat", "COMMIT", `Khu vực ${khuVuc}`);
      print(`✅ KB8 OK: Hoàn tất cập nhật cấu trúc nghề nghiệp hàng loạt.`);
    });
  } catch (e) {
    ghiLog("CapNhatHangLoat", "ABORT", e.message);
    print(`❌ KB8 ABORT: ${e.message}`);
  } finally {
    session.endSession();
  }
}


// ── KỊCH BẢN 9: BÁO CÁO DÂN SỐ (READ-ONLY) ──────────────────────
function kb9_BaoCaoDanSo(khuVucDK) {
  // Sửa lỗi hàm aggregate lồng session bằng cách dùng trực tiếp db.hoKhau
  try {
    const filterStage = khuVucDK ? { $match: { khuVuc: khuVucDK } } : { $match: {} };

    const thongKe = db.hoKhau.aggregate([
      filterStage,
      { $unwind: "$nhanKhau" },
      {
        $group: {
          _id: "$khuVuc",
          tongNK:     { $sum: 1 },
          soNam:      { $sum: { $cond: [{ $eq: ["$nhanKhau.gioiTinh", "Nam"] }, 1, 0] } },
          soNu:       { $sum: { $cond: [{ $eq: ["$nhanKhau.gioiTinh", "Nữ"] }, 1, 0] } },
          soTreEm:    { $sum: { $cond: [{ $lt: [{ $divide: [{ $subtract: [new Date(), "$nhanKhau.ngaySinh"] }, 31557600000] }, 15] }, 1, 0] } },
          soCoTienAn: { $sum: { $cond: [{ $gt: [{ $size: { $ifNull: ["$nhanKhau.tienAnTienSu", []] } }, 0] }, 1, 0] } },
          soTamTru:   { $sum: { $cond: [{ $gt: [{ $size: { $ifNull: ["$nhanKhau.tamTru", []] } }, 0] }, 1, 0] } }
        }
      }
    ]).toArray();

    print("\n📊 BÁO CÁO DÂN SỐ TOÀN DIỆN THỜI ĐIỂM:");
    print("=".repeat(60));
    thongKe.forEach(row => {
      print(`📍 Khu vực: ${row._id}`);
      print(`   -> Tổng dân số: ${row.tongNK} (Nam: ${row.soNam}, Nữ: ${row.soNu})`);
      print(`   -> Nhóm tuổi trẻ em (<15): ${row.soTreEm}`);
      print(`   -> Có tiền án: ${row.soCoTienAn} | Đang tạm lưu trú: ${row.soTamTru}`);
    });
    print("");
  } catch (e) {
    print(`❌ KB9 ERROR: ${e.message}`);
  }
}


// ── KỊCH BẢN 10: OPTIMISTIC LOCK ─────────────────────────────────
function kb10_OptimisticUpdate(maNhanKhau, objectCapNhat, versionHienTai) {
  const session = db.getMongo().startSession();
  try {
    session.startTransaction({
      readConcern:  { level: "majority" },
      writeConcern: { w: "majority", j: true }
    });

    const col = session.getDatabase("nhanKhauDB").hoKhau;
    const result = col.updateOne(
      { "nhanKhau.maNhanKhau": maNhanKhau, "nhanKhau.version": versionHienTai },
      {
        $set: { "nhanKhau.$.ngheNghiep": objectCapNhat.ngheNghiep, "nhanKhau.$.updatedAt": new Date() },
        $inc: { "nhanKhau.$.version": 1 }
      },
      { session: session }
    );

    if (result.matchedCount === 0) {
      session.abortTransaction();
      throw new Error("Xung đột phiên (Conflict): Dữ liệu đã bị sửa đổi ở phiên khác.");
    }

    session.commitTransaction();
    ghiLog("OptimisticUpdate", "COMMIT", `Cập nhật v${versionHienTai} -> v${versionHienTai+1}`);
    print(`✅ KB10 OK: Khóa lạc quan cập nhật thành công.`);
  } catch (e) {
    ghiLog("OptimisticUpdate", "ABORT", e.message);
    print(`❌ KB10 ABORT: ${e.message}`);
  } finally {
    session.endSession();
  }
}

// ── HÀM IN LOG ───────────────────────────────────────────────────
function xemNhatKy() {
  print("\n📋 NHẬT KÝ HỆ THỐNG GIAO DỊCH (ACID TRANSACTION LOG):");
  print("=".repeat(70));
  db.transaction_log.find().sort({ thoiGian: -1 }).forEach(log => {
    const bieuTuong = log.trangThai === "COMMIT" ? "✅" : "❌";
    print(`${bieuTuong} Thao tác: [${log.tenGiaoDich}] -> ${log.ghiChu}`);
  });
  print("");
}