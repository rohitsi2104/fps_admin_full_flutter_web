
# FPS Admin (Flutter) — Complete Web Project

## Run
1. Move this folder out of OneDrive, e.g. `C:\dev\fps_admin`
2. Edit `lib/config.dart` -> set your Django API base URL (must end with `/api/`)
3. In a terminal:
   ```
   flutter pub get
   flutter run -d chrome
   ```

## Notes
- For Web, enable CORS in Django (dev): `CORS_ALLOW_ALL_ORIGINS=True`
- For Android, use base URL `http://10.0.2.2:8000/api/` and allow cleartext if using HTTP.
