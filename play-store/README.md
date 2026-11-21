# Google Play

`google-play.config.json`은 배포 도구가 읽는 설정이다. 패키지, 앱 이름, 기본 언어, 업로드 트랙, AAB 경로를 담는다. 패키지와 이름, AAB 경로는 `godot/config/product.json`과 `godot/export_presets.cfg`의 값과 같아야 하고 `npm run check:native`가 확인한다.

등록 정보는 [docs/05-markets/google-play.md](../docs/05-markets/google-play.md)에, 빌드 절차는 [Android 빌드](../docs/06-release/android-build.md)에 있다. 자격증명은 이 폴더에 두지 않는다.
