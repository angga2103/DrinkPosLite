# 🍹 DrinkPOS Lite — Point of Sale Kedai Minuman Modern & Ringan

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![SQLite](https://img.shields.io/badge/Database-SQLite%20Offline--First-003B57?logo=sqlite&logoColor=white)](https://sqlite.org)
[![Android](https://img.shields.io/badge/Platform-Android%20arm64--v8a-3DDC84?logo=android&logoColor=white)](https://android.com)
[![Developer](https://img.shields.io/badge/Developer-Ansor.Studio-brightgreen)](https://wa.me/6281775700114)

Aplikasi kasir (**Point of Sale**) khusus kedai minuman kekinian dan UMKM (Kedai Es Teh, Kopi, Cokelat, Susu, Jus, dan Boba). Dirancang dengan prinsip **100% Offline-First**, hemat baterai dan memori, serta tidak bergantung pada server luar atau koneksi internet.

---

## 👨‍💻 Identitas Pengembang
- **Pengembang:** Ansor.Studio
- **Kontak Resmi / WhatsApp:** [081775700114](https://wa.me/6281775700114)
- **Tujuan:** Solusi kasir praktis, akurat, dan mandiri tanpa biaya langganan bulanan (*No SaaS, No Cloud Dependency*).

---

## ✨ Fitur Utama

### 1. 📴 100% Offline-First & Integritas Data Lokal
- Seluruh data transaksi, menu, inventaris, dan pelanggan tersimpan aman di database lokal **SQLite (sqflite)**.
- Aplikasi tetap dapat beroperasi penuh di lokasi tanpa sinyal internet.
- Transaksi atomik dengan sistem migrasi database aman tanpa menghapus data saat aplikasi diperbarui.

### 2. 🧮 Manajemen Resep, Gramatur, & Kalkulasi HPP Otomatis
- Pengurangan stok bahan baku secara otomatis per gram/ml sesuai resep saat transaksi terjadi.
- Perhitungan Harga Pokok Penjualan (HPP) per porsi, estimasi laba kotor, dan margin keuntungan secara *real-time*.
- Snapshot HPP historis tersimpan pada setiap transaksi lama sehingga riwayat laba tidak berubah jika harga bahan naik di masa depan.

### 3. 🥤 Kasir POS Cepat & Kustomisasi Varian Minuman
- Antarmuka penjualan responsif dan intuitif dengan tombol sentuh yang jelas.
- Dukungan pilihan ukuran (*Small, Medium, Large*), tingkat gula (*Normal, Sedikit, Tanpa Gula*), tingkat es, dan aneka *topping* (Boba, Jelly, dll.).
- Pengamanan shift: transaksi penjualan ditolak secara otomatis jika shift kasir belum dibuka.

### 4. 💵 Pembayaran Fleksibel (Tunai, QRIS, & Split)
- Mendukung metode pembayaran Tunai, QRIS (verifikasi manual), dan Split Payment (kombinasi Tunai + QRIS).
- Kalkulator kembalian otomatis dan validasi nominal pembayaran.

### 5. 🖨️ Dukungan Printer Thermal Bluetooth ESC/POS (58mm & 80mm)
- Pairing printer langsung dari dalam aplikasi dengan pencarian perangkat Bluetooth otomatis.
- Format struk presisi 32 karakter (58mm) dan 48 karakter (80mm) tanpa teks terpotong.
- Hemat kertas thermal dengan optimasi *feed line* minimal.
- Mendukung cetak logo toko dengan konversi monokrom 1-bit otomatis.

### 6. 🔄 Pembaruan Jarak Jauh Tanpa Internet (WhatsApp Sync `.dpos`)
- Fitur eksklusif bagi Owner: kirim paket update menu, resep racikan, dan stok baru ke WhatsApp kasir dalam berkas terenkripsi `.dpos`.
- Kasir cukup membuka berkas `.dpos` langsung dari WhatsApp dan sistem otomatis memperbarui katalog tanpa Owner harus meminjam HP kasir.

### 7. 📊 Laporan Lengkap & Ekspor Data
- Laporan Penjualan Harian, Mingguan, Bulanan, Produk Terlaris, dan Mutasi Stok.
- Ekspor laporan dalam format **PDF profesional**, tabel **Excel XLSX**, serta ringkasan teks siap kirim ke WhatsApp Owner.
- Hak akses kasir terproteksi: rincian total HPP dan margin laba disembunyikan secara otomatis pada akun kasir.

---

## 🚀 Cara Pemasangan & Menjalankan Aplikasi

### Opsi 1: Pemasangan Langsung di HP Android (Untuk Kasir & Pemilik)
1. Unduh berkas **`app-arm64-v8a-release.apk`** dari tab [Releases](../../releases) pada repositori ini.
2. Buka berkas APK di HP Android Anda.
3. Izinkan instalasi dari sumber tidak dikenal (*Allow from this source*) jika diminta.
4. Buka aplikasi **DrinkPOS Lite**.
5. Masuk menggunakan akun bawaan:
   - **PIN Default:** `1234`
   - Buka menu **Shift dan Kas** untuk mulai bertransaksi jualan.

---

### Opsi 2: Build Otomatis via GitHub Actions (Sangat Praktis & Tanpa Install Apapun di Laptop)
Repositori ini telah dilengkapi dengan sistem CI/CD **GitHub Actions**:
1. Buka tab **Actions** di repositori GitHub ini.
2. Pilih workflow **"Build & Release DrinkPOS Lite APK"**.
3. Klik tombol **Run workflow** (bisa dilakukan lewat browser HP maupun laptop).
4. Tunggu sekitar 3–5 menit hingga proses selesai.
5. Unduh file **`DrinkPOS-Lite-arm64-v8a.apk`** yang otomatis tersedia di bagian *Artifacts* atau tab *Releases*.

---

### Opsi 3: Build Manual dari Source Code (Untuk Pengembang)

#### Prasyarat
- [Flutter SDK](https://flutter.dev) (v3.24 ke atas)
- Android SDK (API Level 34) & Java JDK 17
- Git

#### Langkah Instalasi
1. Clone repositori ini:
   ```bash
   git clone https://github.com/angga2103/DrinkPosLite.git
   cd DrinkPosLite
   ```

2. Unduh seluruh dependensi Flutter:
   ```bash
   flutter pub get
   ```

3. Jalankan pengujian unit komprehensif (21 tes):
   ```bash
   flutter test test/drinkpos_comprehensive_test.dart
   ```

4. Jalankan aplikasi pada mode debug di perangkat / emulator:
   ```bash
   flutter run
   ```

5. Untuk mengompilasi APK rilis siap pakai (arsitektur arm64-v8a):
   ```bash
   flutter build apk --release --target-platform android-arm64
   ```
   Hasil berkas APK siap pakai akan berada di:
   `build/app/outputs/flutter-apk/app-release.apk`

---

## 📁 Struktur Direktori Proyek

```text
lib/
├── core/
│   ├── constants/       # Skema warna, tema, dan konstanta aplikasi
│   ├── database/        # Skema SQLite, migrasi tabel, dan data inisialisasi
│   ├── security/        # Enkripsi PIN, audit log, dan proteksi lockout
│   ├── services/        # Service printer ESC/POS, PDF, Excel, WhatsApp Sync (.dpos)
│   └── utils/           # Helper format mata uang (Rupiah), tanggal, ID unik
├── data/
│   ├── models/          # Model data (Produk, Resep, Transaksi, Shift, Toko, dll.)
│   └── repositories/    # Query SQLite lokal dan logika data
├── presentation/
│   ├── screens/         # Tampilan UI (Dashboard, POS, Stok, Shift, Laporan, Printer)
│   └── widgets/         # Komponen UI modular (Scaffold, Kartu Metrik, Dialog)
└── providers/           # State management berbasis Riverpod
```

---

## 🔒 Lisensi & Hak Cipta
Hak Cipta © 2026 **Ansor.Studio**. Seluruh hak cipta dilindungi undang-undang.
Hubungi **081775700114** untuk informasi lisensi atau kerja sama kustomisasi.
