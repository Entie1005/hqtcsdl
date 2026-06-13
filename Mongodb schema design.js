// =====================================================================
// THIẾT KẾ SCHEMA (DOCUMENT) TRONG MONGODB
// Hệ thống quản lý nhân khẩu — chuyển đổi từ MySQL sang MongoDB
// =====================================================================
// Gồm 2 phần:
//   PHẦN 1 — ERD: Ánh xạ cấu trúc quan hệ MySQL → Document MongoDB
//   PHẦN 2 — DATA: Dữ liệu mẫu thực tế từ bộ dữ liệu nhankhau_full
// =====================================================================

use nhanKhauDB;


// =====================================================================
// PHẦN 1 — ERD: THIẾT KẾ SCHEMA DOCUMENT
// =====================================================================

// ---------------------------------------------------------------------
// 1.1  QUYẾT ĐỊNH EMBEDDING vs REFERENCING
// ---------------------------------------------------------------------
//
//  MySQL (7 bảng quan hệ):
//  ┌─────────┐   1     N  ┌───────────┐   1     N  ┌─────────────┐
//  │ hokhau  │───────────▶│ nhankhau  │───────────▶│tienantiensu │
//  └─────────┘            └───────────┘            └─────────────┘
//                               │ 1     N  ┌──────────┐
//                               └─────────▶│ tamtru   │
//  ┌──────────┐                            └──────────┘
//  │ kethon   │  (độc lập)
//  └──────────┘
//  ┌──────────┐
//  │ chungtu  │  (độc lập)
//  └──────────┘
//  ┌──────────┐
//  │ canbo    │  (độc lập)
//  └──────────┘
//
//  MongoDB (3 collection):
//  ┌─────────────────────────────────────────┐
//  │  Collection: hoKhau                     │
//  │  ┌──────────────────────────────────┐   │
//  │  │  Embedded: nhanKhau[]            │   │
//  │  │  ┌─────────────────────────┐     │   │
//  │  │  │ Embedded: tienAnTienSu[]│     │   │
//  │  │  │ Embedded: tamTru (obj)  │     │   │
//  │  │  └─────────────────────────┘     │   │
//  │  └──────────────────────────────────┘   │
//  └─────────────────────────────────────────┘
//  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐
//  │ Collection:      │  │ Collection:      │  │ Collection:  │
//  │   ketHon         │  │   chungTu        │  │   canBo      │
//  └──────────────────┘  └──────────────────┘  └──────────────┘
//
//  Lý do chọn Embedding cho hoKhau:
//  • nhanKhau luôn được truy vấn cùng hộ khẩu → 1 lần đọc duy nhất
//  • Mỗi hộ khẩu có trung bình 4 nhân khẩu → document nhỏ, không vượt 16MB
//  • tienAnTienSu và tamTru gắn chặt với từng nhân khẩu → embed vào nhanKhau
//  • ketHon và chungTu tham chiếu nhiều bên → collection độc lập
// ---------------------------------------------------------------------


// =====================================================================
// 1.2  SCHEMA COLLECTION: hoKhau
// =====================================================================
// Ánh xạ từ MySQL:
//   hokhau      → document gốc (_id = MaHoKhau)
//   nhankhau    → mảng nhúng nhanKhau[]
//   tienantiensu→ mảng nhúng trong từng phần tử nhanKhau[].tienAnTienSu[]
//   tamtru      → object nhúng trong từng phần tử nhanKhau[].tamTru
// =====================================================================

db.createCollection("hoKhau", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "tenChuHo", "cccdChuHo", "khuVuc", "diaChiHK", "ngayLap"],
      properties: {

        // ── Trường gốc từ bảng hokhau ─────────────────────────────
        _id: {
          bsonType: "string",
          description: "Mã hộ khẩu — PK MySQL MaHoKhau (VD: HK00000001)"
        },
        tenChuHo: {
          bsonType: "string",
          description: "Tên chủ hộ — VARCHAR(50) NOT NULL"
        },
        cccdChuHo: {
          bsonType: "string",
          description: "CCCD chủ hộ — VARCHAR(20) NOT NULL"
        },
        khuVuc: {
          bsonType: "string",
          description: "Khu vực — VARCHAR(50) NOT NULL (VD: Phường 1, Xã Long Phú)"
        },
        diaChiHK: {
          bsonType: "string",
          description: "Địa chỉ hộ khẩu — VARCHAR(100) NOT NULL"
        },
        ngayLap: {
          bsonType: "date",
          description: "Ngày lập hộ khẩu — DATE NOT NULL"
        },

        // ── Mảng nhúng từ bảng nhankhau ───────────────────────────
        nhanKhau: {
          bsonType: "array",
          description: "Danh sách nhân khẩu thuộc hộ — từ bảng nhankhau (FK MaHoKhau)",
          items: {
            bsonType: "object",
            required: ["maNhanKhau", "ten", "ngaySinh", "gioiTinh", "cccd", "ngheNghiep"],
            properties: {

              // Trường từ bảng nhankhau
              maNhanKhau: {
                bsonType: "string",
                description: "PK MySQL MaNhanKhau (VD: NK00000001)"
              },
              ten: {
                bsonType: "string",
                description: "Họ tên nhân khẩu — VARCHAR(50)"
              },
              ngaySinh: {
                bsonType: "date",
                description: "Ngày sinh — DATE"
              },
              gioiTinh: {
                bsonType: "string",
                enum: ["Nam", "Nữ"],
                description: "Giới tính — VARCHAR(10)"
              },
              queQuan: {
                bsonType: "string",
                description: "Quê quán — VARCHAR(20)"
              },
              tonGiao: {
                bsonType: "string",
                description: "Tôn giáo — VARCHAR(20)"
              },
              danToc: {
                bsonType: "string",
                description: "Dân tộc — VARCHAR(20)"
              },
              cccd: {
                bsonType: "string",
                description: "Số CCCD — VARCHAR(20) (unique toàn hệ thống)"
              },
              ngheNghiep: {
                bsonType: "string",
                description: "Nghề nghiệp — VARCHAR(100)"
              },

              // ── Mảng nhúng từ bảng tienantiensu ──────────────────
              tienAnTienSu: {
                bsonType: "array",
                description: "Hồ sơ tiền án tiền sự — từ bảng tienantiensu (FK MaNhanKhau)",
                items: {
                  bsonType: "object",
                  required: ["maTienAnTienSu", "tenTienAnTienSu", "noiXetXu", "ngayThucThi"],
                  properties: {
                    maTienAnTienSu: {
                      bsonType: "string",
                      description: "PK MySQL MaTienAnTienSu (VD: TS00000001)"
                    },
                    tenTienAnTienSu: {
                      bsonType: "string",
                      description: "Loại vụ án — VARCHAR(50)"
                    },
                    noiXetXu: {
                      bsonType: "string",
                      description: "Nơi xét xử — VARCHAR(100)"
                    },
                    ngayThucThi: {
                      bsonType: "date",
                      description: "Ngày thực thi bản án — DATE"
                    }
                  }
                }
              },

              // ── Object nhúng từ bảng tamtru ───────────────────────
              tamTru: {
                bsonType: ["object", "null"],
                description: "Thông tin tạm trú (null nếu không tạm trú) — từ bảng tamtru",
                properties: {
                  maTamTru: {
                    bsonType: "string",
                    description: "PK MySQL MaTamTru (VD: TT00000001)"
                  },
                  tenNoiTamTru: {
                    bsonType: "string",
                    description: "Tên nơi tạm trú — VARCHAR(50)"
                  },
                  diaChi: {
                    bsonType: "string",
                    description: "Địa chỉ tạm trú — VARCHAR(100)"
                  },
                  soDienThoai: {
                    bsonType: "string",
                    description: "Số điện thoại — CHAR(10)"
                  },
                  thoiHan: {
                    bsonType: "string",
                    enum: ["3 tháng", "6 tháng", "12 tháng", "24 tháng"],
                    description: "Thời hạn tạm trú — CHAR(10)"
                  }
                }
              }

            } // end nhanKhau item properties
          } // end nhanKhau items
        } // end nhanKhau array

      } // end root properties
    } // end $jsonSchema
  },
  validationAction: "warn"
});

// INDEX cho collection hoKhau
db.hoKhau.createIndex({ khuVuc: 1 });                                  // lọc theo khu vực
db.hoKhau.createIndex({ tenChuHo: 1 });                                // tìm chủ hộ
db.hoKhau.createIndex({ "nhanKhau.cccd": 1 }, { unique: true, sparse: true });  // tìm theo CCCD
db.hoKhau.createIndex({ "nhanKhau.maNhanKhau": 1 });                   // tìm theo mã NK
db.hoKhau.createIndex({ "nhanKhau.ten": "text" });                     // full-text search tên
db.hoKhau.createIndex({ khuVuc: 1, ngayLap: -1 });                    // composite: khu vực + ngày lập
db.hoKhau.createIndex({ "nhanKhau.ngheNghiep": 1 });                   // thống kê nghề nghiệp
db.hoKhau.createIndex({ "nhanKhau.gioiTinh": 1 });                    // thống kê giới tính
db.hoKhau.createIndex({ "nhanKhau.ngaySinh": 1 });                    // lọc/thống kê độ tuổi
db.hoKhau.createIndex({ "nhanKhau.tienAnTienSu.ngayThucThi": 1 });    // lọc tiền án theo ngày
db.hoKhau.createIndex({ "nhanKhau.tamTru.thoiHan": 1 });              // lọc theo thời hạn tạm trú


// =====================================================================
// 1.3  SCHEMA COLLECTION: ketHon
// =====================================================================
// Ánh xạ từ bảng kethon — giữ nguyên là collection độc lập
// vì kết hôn là sự kiện pháp lý giữa 2 cá nhân khác hộ khẩu.
// Dùng cccd thay vì maNhanKhau để tra cứu linh hoạt hơn.
// =====================================================================

db.createCollection("ketHon", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "chong", "vo", "khuVucDangKy", "ngayDangKy"],
      properties: {
        _id: {
          bsonType: "string",
          description: "Mã kết hôn — PK MySQL MaKetHon (VD: KH00000001)"
        },
        chong: {
          bsonType: "object",
          required: ["ten", "ngaySinh", "danToc", "quocTich", "thuongTamTru", "cccd"],
          description: "Thông tin người chồng — từ các cột TenChong, NgaySinhChong, ...",
          properties: {
            ten:          { bsonType: "string" },
            ngaySinh:     { bsonType: "date"   },
            danToc:       { bsonType: "string" },
            quocTich:     { bsonType: "string" },
            thuongTamTru: { bsonType: "string" },
            cccd:         { bsonType: "string" }
          }
        },
        vo: {
          bsonType: "object",
          required: ["ten", "ngaySinh", "danToc", "quocTich", "thuongTamTru", "cccd"],
          description: "Thông tin người vợ — từ các cột TenVo, NgaySinhVo, ...",
          properties: {
            ten:          { bsonType: "string" },
            ngaySinh:     { bsonType: "date"   },
            danToc:       { bsonType: "string" },
            quocTich:     { bsonType: "string" },
            thuongTamTru: { bsonType: "string" },
            cccd:         { bsonType: "string" }
          }
        },
        khuVucDangKy: {
          bsonType: "string",
          description: "Khu vực đăng ký — VARCHAR(20)"
        },
        ngayDangKy: {
          bsonType: "date",
          description: "Ngày đăng ký kết hôn — DATE"
        }
      }
    }
  },
  validationAction: "warn"
});

db.ketHon.createIndex({ "chong.cccd": 1 });
db.ketHon.createIndex({ "vo.cccd": 1 });
db.ketHon.createIndex({ khuVucDangKy: 1, ngayDangKy: -1 });
db.ketHon.createIndex({ ngayDangKy: -1 });


// =====================================================================
// 1.4  SCHEMA COLLECTION: chungTu
// =====================================================================
// Ánh xạ từ bảng chungtu — collection độc lập.
// Gom thông tin người khai và người mất vào 2 sub-document
// để truy vấn rõ ràng hơn thay vì các cột phẳng.
// =====================================================================

db.createCollection("chungTu", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "nguoiKhai", "nguoiMat", "ngayMat", "khuVucDangKy", "ngayDangKy"],
      properties: {
        _id: {
          bsonType: "string",
          description: "Mã chứng từ — PK MySQL MaChungTu (VD: CT00000001)"
        },
        nguoiKhai: {
          bsonType: "object",
          required: ["ten", "thuongTamTru", "quanHe"],
          description: "Người đứng ra khai tử — TenNguoiKhai, ThuongTamTru, QuanHeVoiNguoiMat",
          properties: {
            ten:         { bsonType: "string" },
            thuongTamTru:{ bsonType: "string" },
            quanHe:      { bsonType: "string", description: "Quan hệ với người mất" }
          }
        },
        nguoiMat: {
          bsonType: "object",
          required: ["ten", "ngaySinh", "danToc", "quocTich", "cccd"],
          description: "Thông tin người mất — TenNguoiMat, NgaySinh, DanToc, QuocTich, CCCD",
          properties: {
            ten:      { bsonType: "string" },
            ngaySinh: { bsonType: "date"   },
            danToc:   { bsonType: "string" },
            quocTich: { bsonType: "string" },
            cccd:     { bsonType: "string" }
          }
        },
        ngayMat: {
          bsonType: "date",
          description: "Ngày mất — DATE"
        },
        gioMat: {
          bsonType: "string",
          description: "Giờ mất — CHAR(5), VD: 03:24"
        },
        khuVucDangKy: {
          bsonType: "string",
          description: "Khu vực đăng ký khai tử — VARCHAR(20)"
        },
        ngayDangKy: {
          bsonType: "date",
          description: "Ngày đăng ký khai tử — DATE"
        }
      }
    }
  },
  validationAction: "warn"
});

db.chungTu.createIndex({ "nguoiMat.cccd": 1 });
db.chungTu.createIndex({ ngayMat: -1 });
db.chungTu.createIndex({ khuVucDangKy: 1, ngayMat: -1 });
db.chungTu.createIndex({ ngayDangKy: -1 });


// =====================================================================
// 1.5  SCHEMA COLLECTION: canBo
// =====================================================================
// Ánh xạ từ bảng canbo — collection đơn giản, giữ nguyên cấu trúc.
// Mật khẩu nên được hash trong hệ thống thực tế.
// =====================================================================

db.createCollection("canBo", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "matKhau"],
      properties: {
        _id: {
          bsonType: "string",
          description: "Tài khoản cán bộ — PK MySQL TaiKhoan (VD: canbo01)"
        },
        matKhau: {
          bsonType: "string",
          description: "Mật khẩu — CHAR(20) (nên hash bcrypt trong thực tế)"
        }
      }
    }
  },
  validationAction: "warn"
});

db.canBo.createIndex({ _id: 1 }); // PK mặc định, đăng nhập nhanh


// =====================================================================
// PHẦN 2 — DATA: DỮ LIỆU MẪU THỰC TẾ
// Chuyển đổi toàn bộ từ INSERT INTO MySQL sang insertMany() MongoDB
// Bao gồm:
//   • 20 hộ khẩu (HK00000001 → HK00000020) với nhân khẩu nhúng bên trong
//   • Nhân khẩu tương ứng với từng hộ khẩu
//   • Tiền án tiền sự nhúng vào nhân khẩu liên quan
//   • Tạm trú nhúng vào nhân khẩu liên quan
//   • 10 kết hôn (KH00000001 → KH00000010)
//   • 10 chứng từ khai tử (CT00000001 → CT00000010)
//   • 10 cán bộ (canbo01 → canbo10)
// =====================================================================


// =====================================================================
// 2.1  DỮ LIỆU COLLECTION: hoKhau
// =====================================================================
// Các nhân khẩu được nhúng vào đúng hộ khẩu theo MaHoKhau trong MySQL.
// Tiền án tiền sự và tạm trú được tra cứu và nhúng vào đúng nhân khẩu.
//
// Mapping tienantiensu → nhankhau:
//   TS00000002  → NK00000016  (HK00000173 → ngoài 20 HK mẫu)
//   TS00000008  → NK00000080  (ngoài 20 HK mẫu)
//   ... (các bản ghi TS khác đều thuộc NK ngoài phạm vi 20 HK đầu)
//   → Nhúng TS vào NK trong 20 HK được chọn khi có dữ liệu
//
// Mapping tamtru → nhankhau (trong 20 HK đầu):
//   TT00000008  → NK00000090  → HK của NK00000090 (kiểm tra data thực)
//   → Nhúng vào đúng NK nếu thuộc 20 HK mẫu
// =====================================================================

db.hoKhau.insertMany([

  // ── HK00000001 ────────────────────────────────────────────────────
  {
    _id: "HK00000001",
    tenChuHo: "Hoàng Quốc Xuân",
    cccdChuHo: "019600133890",
    khuVuc: "Phường 2",
    diaChiHK: "Số 13, Đường Phan Bội Châu, Phường 2, Bắc Ninh",
    ngayLap: new Date("2008-12-01"),
    nhanKhau: [
      // NK00000141 thuộc HK00000001? — theo data: NK00000001→HK00000141
      // Các NK trong HK00000001 từ data gốc (NK có MaHoKhau='HK00000001')
      // Data mẫu không có NK nào trong 20 NK đầu thuộc HK00000001
      // → Để trống mảng (hộ khẩu chưa có nhân khẩu trong 20 NK mẫu đầu)
    ]
  },

  // ── HK00000002 ────────────────────────────────────────────────────
  {
    _id: "HK00000002",
    tenChuHo: "Nguyễn Thanh Thảo",
    cccdChuHo: "054235116155",
    khuVuc: "Thị trấn Bắc Giang",
    diaChiHK: "Số 215, Đường Lý Thường Kiệt, Thị trấn Bắc Giang, Hải Dương",
    ngayLap: new Date("2011-11-12"),
    nhanKhau: [
      {
        maNhanKhau: "NK00000012",
        ten: "Phan Quốc Quân",
        ngaySinh: new Date("1969-05-05"),
        gioiTinh: "Nam",
        queQuan: "Hải Dương",
        tonGiao: "Phật giáo",
        danToc: "Nùng",
        cccd: "016091779827",
        ngheNghiep: "Thất nghiệp",
        tienAnTienSu: [],
        tamTru: null
      }
    ]
  },

  // ── HK00000003 ────────────────────────────────────────────────────
  {
    _id: "HK00000003",
    tenChuHo: "Tô Đức Đạt",
    cccdChuHo: "059310341316",
    khuVuc: "Phường 1",
    diaChiHK: "Số 236, Đường Nguyễn Huệ, Phường 1, Cần Thơ",
    ngayLap: new Date("2012-06-20"),
    nhanKhau: []
  },

  // ── HK00000004 ────────────────────────────────────────────────────
  {
    _id: "HK00000004",
    tenChuHo: "Phan Thùy Chi",
    cccdChuHo: "092832764835",
    khuVuc: "Xã Long Phú",
    diaChiHK: "Số 187, Đường Trần Phú, Xã Long Phú, Đà Nẵng",
    ngayLap: new Date("2002-07-05"),
    nhanKhau: [
      {
        maNhanKhau: "NK00000003",
        ten: "Phan Mai Hoa",
        ngaySinh: new Date("1973-08-05"),
        gioiTinh: "Nữ",
        queQuan: "Vĩnh Phúc",
        tonGiao: "Phật giáo",
        danToc: "Nùng",
        cccd: "064208737530",
        ngheNghiep: "Giáo viên",
        tienAnTienSu: [],
        tamTru: null
      }
    ]
  },

  // ── HK00000005 ────────────────────────────────────────────────────
  {
    _id: "HK00000005",
    tenChuHo: "Lê Bích Yến",
    cccdChuHo: "053767242388",
    khuVuc: "Phường 4",
    diaChiHK: "Số 17, Đường Đinh Tiên Hoàng, Phường 4, Cần Thơ",
    ngayLap: new Date("2011-10-14"),
    nhanKhau: []
  },

  // ── HK00000006 ────────────────────────────────────────────────────
  {
    _id: "HK00000006",
    tenChuHo: "Hoàng Tuấn Tuấn",
    cccdChuHo: "010122691669",
    khuVuc: "Xã Hùng Sơn",
    diaChiHK: "Số 220, Đường Hai Bà Trưng, Xã Hùng Sơn, Đà Nẵng",
    ngayLap: new Date("2020-12-29"),
    nhanKhau: []
  },

  // ── HK00000007 ────────────────────────────────────────────────────
  {
    _id: "HK00000007",
    tenChuHo: "Bùi Ngọc Ngân",
    cccdChuHo: "062704828148",
    khuVuc: "Thị trấn Bắc Giang",
    diaChiHK: "Số 129, Đường Lê Lợi, Thị trấn Bắc Giang, TP. Hồ Chí Minh",
    ngayLap: new Date("2008-12-02"),
    nhanKhau: []
  },

  // ── HK00000008 ────────────────────────────────────────────────────
  {
    _id: "HK00000008",
    tenChuHo: "Lưu Thành Tuấn",
    cccdChuHo: "001543039117",
    khuVuc: "Phường 3",
    diaChiHK: "Số 192, Đường Trần Phú, Phường 3, Vĩnh Phúc",
    ngayLap: new Date("2003-02-07"),
    nhanKhau: []
  },

  // ── HK00000009 ────────────────────────────────────────────────────
  {
    _id: "HK00000009",
    tenChuHo: "Võ Tuấn Đạt",
    cccdChuHo: "063834657871",
    khuVuc: "Thị trấn Bắc Giang",
    diaChiHK: "Số 65, Đường Trần Phú, Thị trấn Bắc Giang, Hải Dương",
    ngayLap: new Date("2011-02-13"),
    nhanKhau: []
  },

  // ── HK00000010 ────────────────────────────────────────────────────
  {
    _id: "HK00000010",
    tenChuHo: "Cao Hữu An",
    cccdChuHo: "010310518347",
    khuVuc: "Phường 4",
    diaChiHK: "Số 33, Đường Đinh Tiên Hoàng, Phường 4, Hà Nội",
    ngayLap: new Date("2009-08-11"),
    nhanKhau: [
      {
        maNhanKhau: "NK00000010",
        ten: "Hồ Công Bình",
        ngaySinh: new Date("1999-12-26"),
        gioiTinh: "Nam",
        queQuan: "Vĩnh Phúc",
        tonGiao: "Không",
        danToc: "Tày",
        cccd: "099488375503",
        ngheNghiep: "Lái xe",
        tienAnTienSu: [],
        tamTru: null
      }
    ]
  },

  // ── HK00000011 ────────────────────────────────────────────────────
  {
    _id: "HK00000011",
    tenChuHo: "Ngô Bích Dung",
    cccdChuHo: "016566701065",
    khuVuc: "Thị trấn Bắc Giang",
    diaChiHK: "Số 68, Đường Ngô Quyền, Thị trấn Bắc Giang, Bắc Ninh",
    ngayLap: new Date("2004-11-25"),
    nhanKhau: []
  },

  // ── HK00000012 ────────────────────────────────────────────────────
  {
    _id: "HK00000012",
    tenChuHo: "Hoàng Lan Hà",
    cccdChuHo: "047317810801",
    khuVuc: "Phường 4",
    diaChiHK: "Số 99, Đường Lý Thường Kiệt, Phường 4, Vĩnh Phúc",
    ngayLap: new Date("2010-08-08"),
    nhanKhau: []
  },

  // ── HK00000013 ────────────────────────────────────────────────────
  {
    _id: "HK00000013",
    tenChuHo: "Hồ Văn Giang",
    cccdChuHo: "060647468723",
    khuVuc: "Phường 3",
    diaChiHK: "Số 209, Đường Ngô Quyền, Phường 3, Hải Dương",
    ngayLap: new Date("2013-04-23"),
    nhanKhau: []
  },

  // ── HK00000014 ────────────────────────────────────────────────────
  {
    _id: "HK00000014",
    tenChuHo: "Trần Hùng Tuấn",
    cccdChuHo: "088208121913",
    khuVuc: "Phường 4",
    diaChiHK: "Số 30, Đường Lê Lợi, Phường 4, Đà Nẵng",
    ngayLap: new Date("2018-02-10"),
    nhanKhau: []
  },

  // ── HK00000015 ────────────────────────────────────────────────────
  {
    _id: "HK00000015",
    tenChuHo: "Lưu Quốc Sơn",
    cccdChuHo: "099854353462",
    khuVuc: "Phường 2",
    diaChiHK: "Số 292, Đường Lý Thường Kiệt, Phường 2, Thái Nguyên",
    ngayLap: new Date("2013-06-16"),
    nhanKhau: []
  },

  // ── HK00000016 ────────────────────────────────────────────────────
  {
    _id: "HK00000016",
    tenChuHo: "Lưu Mai Dung",
    cccdChuHo: "018384251354",
    khuVuc: "Xã Long Phú",
    diaChiHK: "Số 162, Đường Nguyễn Huệ, Xã Long Phú, Hà Nội",
    ngayLap: new Date("2007-01-28"),
    nhanKhau: []
  },

  // ── HK00000017 ────────────────────────────────────────────────────
  {
    _id: "HK00000017",
    tenChuHo: "Tô Đức Dũng",
    cccdChuHo: "024118244935",
    khuVuc: "Xã Long Phú",
    diaChiHK: "Số 279, Đường Phan Bội Châu, Xã Long Phú, Thái Nguyên",
    ngayLap: new Date("2009-02-17"),
    nhanKhau: []
  },

  // ── HK00000018 ────────────────────────────────────────────────────
  {
    _id: "HK00000018",
    tenChuHo: "Lê Công Long",
    cccdChuHo: "000524278680",
    khuVuc: "Phường 5",
    diaChiHK: "Số 259, Đường Ngô Quyền, Phường 5, Hải Phòng",
    ngayLap: new Date("2005-01-06"),
    nhanKhau: []
  },

  // ── HK00000019 ────────────────────────────────────────────────────
  {
    _id: "HK00000019",
    tenChuHo: "Ngô Minh Bình",
    cccdChuHo: "045053315869",
    khuVuc: "Phường 2",
    diaChiHK: "Số 77, Đường Lê Lợi, Phường 2, Đà Nẵng",
    ngayLap: new Date("2006-12-07"),
    nhanKhau: []
  },

  // ── HK00000020 ────────────────────────────────────────────────────
  {
    _id: "HK00000020",
    tenChuHo: "Huỳnh Thành Sơn",
    cccdChuHo: "034216073375",
    khuVuc: "Phường 4",
    diaChiHK: "Số 84, Đường Trần Phú, Phường 4, Cần Thơ",
    ngayLap: new Date("2013-09-09"),
    nhanKhau: []
  }

]); // end hoKhau.insertMany


// =====================================================================
// 2.1b  BỔ SUNG NHÂN KHẨU VÀO HỘ KHẨU (KHÔNG THUỘC 20 HK ĐẦU)
// Dùng updateOne + $push để thêm nhân khẩu vào hộ khẩu đúng
// khi hộ khẩu đã tồn tại trong collection (từ data > HK00000020)
// =====================================================================
//
// Ví dụ thêm NK00000001 vào HK00000141 (nếu HK đó đã được insert):
// db.hoKhau.updateOne(
//   { _id: "HK00000141" },
//   { $push: { nhanKhau: {
//       maNhanKhau: "NK00000001", ten: "Đỗ Văn Quân",
//       ngaySinh: new Date("2007-06-13"), gioiTinh: "Nam",
//       queQuan: "Hải Phòng", tonGiao: "Hòa Hảo", danToc: "Ê Đê",
//       cccd: "009010016761", ngheNghiep: "Cán bộ nhà nước",
//       tienAnTienSu: [], tamTru: null
//   }}}
// );
//
// Nhúng tiền án vào nhân khẩu đúng:
// db.hoKhau.updateOne(
//   { "nhanKhau.cccd": "042043805719" },     // NK00000016 (HK00000173)
//   { $push: { "nhanKhau.$.tienAnTienSu": {
//       maTienAnTienSu: "TS00000002",
//       tenTienAnTienSu: "Cố ý gây thương tích",
//       noiXetXu: "TAND tỉnh Hải Dương",
//       ngayThucThi: new Date("2010-08-06")
//   }}}
// );


// =====================================================================
// 2.2  DỮ LIỆU COLLECTION: ketHon
// =====================================================================

db.ketHon.insertMany([
  {
    _id: "KH00000001",
    chong: {
      ten: "Nguyễn Văn Sơn",
      ngaySinh: new Date("1960-12-14"),
      danToc: "Gia Rai",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 74, Đường Ngô Quyền, Hải Dương",
      cccd: "005646160762"
    },
    vo: {
      ten: "Hồ Thùy Hoa",
      ngaySinh: new Date("1991-10-16"),
      danToc: "Gia Rai",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 182, Đường Lê Lợi, Hà Nội",
      cccd: "095372346176"
    },
    khuVucDangKy: "Phường 3",
    ngayDangKy: new Date("2000-01-01")
  },
  {
    _id: "KH00000002",
    chong: {
      ten: "Phạm Hữu Hải",
      ngaySinh: new Date("1995-04-13"),
      danToc: "Hmông",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 59, Đường Lê Lợi, Thái Nguyên",
      cccd: "044164231654"
    },
    vo: {
      ten: "Đặng Ngọc Hoa",
      ngaySinh: new Date("1980-08-15"),
      danToc: "Thái",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 238, Đường Ngô Quyền, Cần Thơ",
      cccd: "085760634942"
    },
    khuVucDangKy: "Xã Hùng Sơn",
    ngayDangKy: new Date("1992-01-08")
  },
  {
    _id: "KH00000003",
    chong: {
      ten: "Võ Công Cường",
      ngaySinh: new Date("1981-03-26"),
      danToc: "Nùng",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 175, Đường Nguyễn Huệ, Vĩnh Phúc",
      cccd: "087017999324"
    },
    vo: {
      ten: "Huỳnh Thị Hà",
      ngaySinh: new Date("1972-11-15"),
      danToc: "Gia Rai",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 113, Đường Ngô Quyền, Hải Phòng",
      cccd: "044172345653"
    },
    khuVucDangKy: "Thị trấn Bắc Giang",
    ngayDangKy: new Date("2007-06-09")
  },
  {
    _id: "KH00000004",
    chong: {
      ten: "Cao Đức Tài",
      ngaySinh: new Date("1985-07-31"),
      danToc: "Kinh",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 85, Đường Đinh Tiên Hoàng, Hải Phòng",
      cccd: "085362689047"
    },
    vo: {
      ten: "Huỳnh Bích Vân",
      ngaySinh: new Date("1979-06-18"),
      danToc: "Khmer",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 33, Đường Lê Lợi, Hà Nội",
      cccd: "095385574216"
    },
    khuVucDangKy: "Phường 5",
    ngayDangKy: new Date("2000-07-08")
  },
  {
    _id: "KH00000005",
    chong: {
      ten: "Bùi Hùng Đạt",
      ngaySinh: new Date("1960-09-19"),
      danToc: "Kinh",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 298, Đường Lý Thường Kiệt, Hải Dương",
      cccd: "081460476143"
    },
    vo: {
      ten: "Dương Tuyết Vân",
      ngaySinh: new Date("1971-10-01"),
      danToc: "Khmer",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 109, Đường Ngô Quyền, Hà Nội",
      cccd: "066187564672"
    },
    khuVucDangKy: "Xã Tân Hòa",
    ngayDangKy: new Date("2023-11-14")
  },
  {
    _id: "KH00000006",
    chong: {
      ten: "Vũ Công Xuân",
      ngaySinh: new Date("1995-01-31"),
      danToc: "Tày",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 189, Đường Phan Bội Châu, TP. Hồ Chí Minh",
      cccd: "085899002772"
    },
    vo: {
      ten: "Cao Ngọc An",
      ngaySinh: new Date("1994-11-09"),
      danToc: "Gia Rai",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 158, Đường Đinh Tiên Hoàng, Hà Nội",
      cccd: "078604356605"
    },
    khuVucDangKy: "Phường 1",
    ngayDangKy: new Date("2000-03-22")
  },
  {
    _id: "KH00000007",
    chong: {
      ten: "Vũ Anh Long",
      ngaySinh: new Date("1979-01-21"),
      danToc: "Ê Đê",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 261, Đường Lý Thường Kiệt, Bắc Ninh",
      cccd: "006773067182"
    },
    vo: {
      ten: "Huỳnh Thanh Thảo",
      ngaySinh: new Date("1978-05-28"),
      danToc: "Dao",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 295, Đường Phan Bội Châu, TP. Hồ Chí Minh",
      cccd: "090878865385"
    },
    khuVucDangKy: "Xã Hùng Sơn",
    ngayDangKy: new Date("1992-02-04")
  },
  {
    _id: "KH00000008",
    chong: {
      ten: "Hồ Anh Hải",
      ngaySinh: new Date("1985-09-08"),
      danToc: "Hmông",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 105, Đường Phan Bội Châu, Bắc Giang",
      cccd: "089876055049"
    },
    vo: {
      ten: "Hoàng Thanh Dung",
      ngaySinh: new Date("1991-02-25"),
      danToc: "Dao",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 31, Đường Phan Bội Châu, Vĩnh Phúc",
      cccd: "061867066320"
    },
    khuVucDangKy: "Phường 2",
    ngayDangKy: new Date("2008-01-16")
  },
  {
    _id: "KH00000009",
    chong: {
      ten: "Huỳnh Hùng An",
      ngaySinh: new Date("1981-04-15"),
      danToc: "Mường",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 298, Đường Trần Phú, Vĩnh Phúc",
      cccd: "091982718265"
    },
    vo: {
      ten: "Phan Bích Trang",
      ngaySinh: new Date("1964-01-21"),
      danToc: "Dao",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 4, Đường Hai Bà Trưng, Hải Phòng",
      cccd: "094269420398"
    },
    khuVucDangKy: "Phường 4",
    ngayDangKy: new Date("1993-11-28")
  },
  {
    _id: "KH00000010",
    chong: {
      ten: "Vũ Thành Mạnh",
      ngaySinh: new Date("1990-10-27"),
      danToc: "Ê Đê",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 10, Đường Nguyễn Huệ, Hải Phòng",
      cccd: "059967069219"
    },
    vo: {
      ten: "Bùi Tuyết Trang",
      ngaySinh: new Date("1968-07-07"),
      danToc: "Kinh",
      quocTich: "Việt Nam",
      thuongTamTru: "Số 189, Đường Phan Bội Châu, Thái Nguyên",
      cccd: "082438843021"
    },
    khuVucDangKy: "Xã Long Phú",
    ngayDangKy: new Date("2022-07-05")
  }

]); // end ketHon.insertMany


// =====================================================================
// 2.3  DỮ LIỆU COLLECTION: chungTu
// =====================================================================

db.chungTu.insertMany([
  {
    _id: "CT00000001",
    nguoiKhai: {
      ten: "Phan Mai Vân",
      thuongTamTru: "Số 276, Đường Đinh Tiên Hoàng, Bắc Giang",
      quanHe: "Con gái"
    },
    nguoiMat: {
      ten: "Tô Mai Oanh",
      ngaySinh: new Date("1950-11-02"),
      danToc: "Ê Đê",
      quocTich: "Việt Nam",
      cccd: "090984128655"
    },
    ngayMat: new Date("2023-04-10"),
    gioMat: "03:24",
    khuVucDangKy: "Xã Long Phú",
    ngayDangKy: new Date("2023-04-22")
  },
  {
    _id: "CT00000002",
    nguoiKhai: {
      ten: "Phan Tuấn Hải",
      thuongTamTru: "Số 50, Đường Lý Thường Kiệt, Hải Phòng",
      quanHe: "Con gái"
    },
    nguoiMat: {
      ten: "Trần Hữu Xuân",
      ngaySinh: new Date("1925-10-31"),
      danToc: "Khmer",
      quocTich: "Việt Nam",
      cccd: "063429242195"
    },
    ngayMat: new Date("2020-10-12"),
    gioMat: "23:53",
    khuVucDangKy: "Phường 4",
    ngayDangKy: new Date("2020-11-06")
  },
  {
    _id: "CT00000003",
    nguoiKhai: {
      ten: "Cao Quốc Giang",
      thuongTamTru: "Số 33, Đường Đinh Tiên Hoàng, Bắc Giang",
      quanHe: "Mẹ"
    },
    nguoiMat: {
      ten: "Đặng Quốc Cường",
      ngaySinh: new Date("1946-07-13"),
      danToc: "Hmông",
      quocTich: "Việt Nam",
      cccd: "013315553015"
    },
    ngayMat: new Date("2010-01-09"),
    gioMat: "01:12",
    khuVucDangKy: "Phường 1",
    ngayDangKy: new Date("2010-02-04")
  },
  {
    _id: "CT00000004",
    nguoiKhai: {
      ten: "Đặng Thị Trang",
      thuongTamTru: "Số 226, Đường Nguyễn Huệ, TP. Hồ Chí Minh",
      quanHe: "Con trai"
    },
    nguoiMat: {
      ten: "Đỗ Mai Xuân",
      ngaySinh: new Date("1947-03-11"),
      danToc: "Nùng",
      quocTich: "Việt Nam",
      cccd: "057663454182"
    },
    ngayMat: new Date("2004-05-29"),
    gioMat: "04:26",
    khuVucDangKy: "Xã Hùng Sơn",
    ngayDangKy: new Date("2004-06-26")
  },
  {
    _id: "CT00000005",
    nguoiKhai: {
      ten: "Bùi Thanh Bích",
      thuongTamTru: "Số 214, Đường Phan Bội Châu, TP. Hồ Chí Minh",
      quanHe: "Con gái"
    },
    nguoiMat: {
      ten: "Ngô Quốc Quân",
      ngaySinh: new Date("1954-02-20"),
      danToc: "Ê Đê",
      quocTich: "Việt Nam",
      cccd: "010082242168"
    },
    ngayMat: new Date("2006-05-05"),
    gioMat: "13:52",
    khuVucDangKy: "Thị trấn Bắc Giang",
    ngayDangKy: new Date("2006-06-04")
  },
  {
    _id: "CT00000006",
    nguoiKhai: {
      ten: "Hoàng Quốc Tuấn",
      thuongTamTru: "Số 183, Đường Hai Bà Trưng, Bắc Giang",
      quanHe: "Cha"
    },
    nguoiMat: {
      ten: "Hoàng Thị Vân",
      ngaySinh: new Date("1937-05-13"),
      danToc: "Khmer",
      quocTich: "Việt Nam",
      cccd: "079100593257"
    },
    ngayMat: new Date("2005-10-22"),
    gioMat: "04:35",
    khuVucDangKy: "Xã Long Phú",
    ngayDangKy: new Date("2005-10-24")
  },
  {
    _id: "CT00000007",
    nguoiKhai: {
      ten: "Huỳnh Minh An",
      thuongTamTru: "Số 24, Đường Ngô Quyền, Hải Phòng",
      quanHe: "Em"
    },
    nguoiMat: {
      ten: "Hoàng Thùy Hoa",
      ngaySinh: new Date("1969-12-04"),
      danToc: "Dao",
      quocTich: "Việt Nam",
      cccd: "012951452058"
    },
    ngayMat: new Date("2001-01-12"),
    gioMat: "22:59",
    khuVucDangKy: "Phường 3",
    ngayDangKy: new Date("2001-02-11")
  },
  {
    _id: "CT00000008",
    nguoiKhai: {
      ten: "Nguyễn Lan Bích",
      thuongTamTru: "Số 148, Đường Lê Lợi, Bắc Giang",
      quanHe: "Vợ"
    },
    nguoiMat: {
      ten: "Nguyễn Lan Phương",
      ngaySinh: new Date("1946-12-14"),
      danToc: "Dao",
      quocTich: "Việt Nam",
      cccd: "047695090418"
    },
    ngayMat: new Date("2022-08-27"),
    gioMat: "10:27",
    khuVucDangKy: "Xã Tân Hòa",
    ngayDangKy: new Date("2022-09-19")
  },
  {
    _id: "CT00000009",
    nguoiKhai: {
      ten: "Phan Thị Dung",
      thuongTamTru: "Số 200, Đường Đinh Tiên Hoàng, Đà Nẵng",
      quanHe: "Cha"
    },
    nguoiMat: {
      ten: "Vũ Tuấn Xuân",
      ngaySinh: new Date("1964-02-25"),
      danToc: "Gia Rai",
      quocTich: "Việt Nam",
      cccd: "088765699313"
    },
    ngayMat: new Date("2017-06-19"),
    gioMat: "21:03",
    khuVucDangKy: "Xã Tân Hòa",
    ngayDangKy: new Date("2017-07-10")
  },
  {
    _id: "CT00000010",
    nguoiKhai: {
      ten: "Hoàng Hùng An",
      thuongTamTru: "Số 46, Đường Nguyễn Huệ, Bắc Ninh",
      quanHe: "Cha"
    },
    nguoiMat: {
      ten: "Võ Anh Yên",
      ngaySinh: new Date("1944-11-09"),
      danToc: "Dao",
      quocTich: "Việt Nam",
      cccd: "019903803514"
    },
    ngayMat: new Date("2023-05-16"),
    gioMat: "18:51",
    khuVucDangKy: "Xã An Bình",
    ngayDangKy: new Date("2023-06-09")
  }

]); // end chungTu.insertMany


// =====================================================================
// 2.4  DỮ LIỆU COLLECTION: canBo
// =====================================================================

db.canBo.insertMany([
  { _id: "canbo01", matKhau: "Cb@3833" },
  { _id: "canbo02", matKhau: "Cb@4407" },
  { _id: "canbo03", matKhau: "Cb@1780" },
  { _id: "canbo04", matKhau: "Cb@1210" },
  { _id: "canbo05", matKhau: "Cb@4437" },
  { _id: "canbo06", matKhau: "Cb@7854" },
  { _id: "canbo07", matKhau: "Cb@1175" },
  { _id: "canbo08", matKhau: "Cb@8402" },
  { _id: "canbo09", matKhau: "Cb@3205" },
  { _id: "canbo10", matKhau: "Cb@3113" }
]); // end canBo.insertMany


// =====================================================================
// KIỂM TRA DỮ LIỆU SAU KHI CHÈN
// =====================================================================

// Đếm document mỗi collection
db.hoKhau.countDocuments();       // → 20
db.ketHon.countDocuments();       // → 10
db.chungTu.countDocuments();      // → 10
db.canBo.countDocuments();        // → 10

// Xem cấu trúc document hoKhau đầy đủ
db.hoKhau.findOne({ _id: "HK00000002" });
db.hoKhau.findOne({ _id: "HK00000004" });
db.hoKhau.findOne({ _id: "HK00000010" });

// Tìm nhân khẩu theo CCCD
db.hoKhau.findOne(
  { "nhanKhau.cccd": "064208737530" },
  { tenChuHo: 1, khuVuc: 1, "nhanKhau.$": 1 }
);

// Thống kê nhân khẩu theo khu vực
db.hoKhau.aggregate([
  { $group: { _id: "$khuVuc", soHoKhau: { $sum: 1 } } },
  { $sort: { soHoKhau: -1 } }
]);

// Xem kết hôn theo năm
db.ketHon.aggregate([
  { $group: { _id: { $year: "$ngayDangKy" }, soCap: { $sum: 1 } } },
  { $sort: { _id: -1 } }
]);

// Xem chứng từ khai tử mới nhất
db.chungTu.find({}, { "nguoiMat.ten": 1, ngayMat: 1, khuVucDangKy: 1 })
  .sort({ ngayMat: -1 })
  .limit(5);

// Liệt kê tất cả index đã tạo
db.hoKhau.getIndexes();
db.ketHon.getIndexes();
db.chungTu.getIndexes();
db.canBo.getIndexes();