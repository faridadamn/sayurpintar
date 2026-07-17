# SayurPintar Landing Site

Landing page statis untuk memperkenalkan SayurPintar sebagai asisten digital bagi tukang sayur keliling.

## Preview lokal

Buka `index.html` langsung di browser, atau jalankan static server:

```bash
cd site
python -m http.server 8080
```

Lalu buka `http://localhost:8080`.

## Struktur

- `index.html` — konten dan struktur landing page
- `styles.css` — desain responsif dan mockup aplikasi berbasis CSS
- `script.js` — animasi scroll dan interaksi formulir demo

## Deployment

Folder `site` dapat dijadikan root directory di Vercel, Netlify, Cloudflare Pages, atau static hosting lain tanpa proses build.

### Vercel

1. Import repository.
2. Set **Root Directory** ke `site`.
3. Pilih framework preset **Other**.
4. Deploy tanpa build command.

## Catatan formulir

Formulir daftar tunggu saat ini hanya simulasi di sisi browser dan belum menyimpan data. Hubungkan submit handler ke backend/API sebelum digunakan untuk produksi.