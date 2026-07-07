# CodeLens AR

Kod tabanlarını Artırılmış Gerçeklik (AR) üzerinden görselleştiren bir Flutter/ARCore mobil uygulaması. Bir GitHub reposunun URL'sini verirsiniz, uygulama repoyu analiz edip class/function/component yapısını ve aralarındaki bağımlılıkları telefonunuzun kamerası üzerinden gerçek dünyaya 3D nesneler olarak yerleştirir.

Backend/parser servisi: [codelens-parser](https://github.com/denizkilinc2/codelens-parser)

## Özellikler

- **Gerçek zamanlı kod analizi** — bir repo URL'si girip backend'e gönderir, gelen graph'ı AR sahnesine dönüştürür
- **Grup bazlı toplu yerleştirme** — tek tek dokunmak yerine, ilgili tüm kod yapılarını (ör. "Service Worker" grubu) tek dokunuşla sahneye ekler
- **Gerçek bağımlılık çizgileri** — import/kullanım ilişkisi tespit edilen kod yapıları arasında 3D bağlantı çizgileri çizer
- **Bağımlılık diyagramı** — dosyalar arası ilişkileri gösteren, yakınlaştırılabilir 2D graf ekranı
- **Önem sıralaması** — LLM tarafından üretilen önem skoruna göre kod yapılarını sıralayan liste
- **Gerçek kaynak kodu görüntüleme** — her node'a dokununca ilgili kod parçacığını, açıklamasını ve meta verilerini gösteren detay penceresi

## Gereksinimler

- ARCore destekleyen fiziksel bir Android cihaz (emülatör ve ARCore desteklemeyen cihazlar çalışmaz — kamera/sensör gerektirir)
- Flutter SDK
- Çalışan bir [codelens-parser](https://github.com/denizkilinc2/codelens-parser) backend örneği (yerel ağda erişilebilir)

## Kurulum

```bash
flutter pub get
```

`lib/main.dart` içindeki backend adresini kendi sunucunun IP'siyle güncelle:
```dart
final _apiService = AnalysisApiService(baseUrl: 'http://SENIN_IP_ADRESIN:3000');
```

```bash
flutter run
```

## Mimari

```
Kullanıcı
  → GitHub repo URL'si girer
  → Backend'e HTTP isteği (codelens-parser)
  → Backend: clone + AST analiz + LLM enrichment
  → JSON graph (nodes + edges) → Flutter'a döner
  → Kullanıcı bir grup seçer
  → Düzleme dokunur
  → Seçilen gruptaki TÜM kod yapıları tek seferde,
    aralarındaki gerçek bağlantılarla birlikte AR sahnesine yerleşir
```

## Teknoloji

- **Flutter** + **ar_flutter_plugin** (ARCore entegrasyonu — plane detection, anchor yönetimi, node render)
- **http** paketi ile backend API iletişimi

## Bilinen Sınırlamalar

- `ar_flutter_plugin` bakımı yavaş ilerleyen bir paket; modern Android araç zinciriyle (AGP 8+, Kotlin 2.x, Jetifier) uyumluluk için birkaç yapılandırma düzeltmesi gerekir (namespace, JVM target, manifest merge çakışmaları)
- 3D modeller, native render motorunun (Sceneform/Filament) özel üretim `.glb` dosyalarını kabul etmemesi nedeniyle Khronos'un kanıtlanmış örnek varlıklarından (Box) seçilmiştir; özel renkli/şekilli model üretimi şu an desteklenmiyor
- iOS/ARKit desteği yok — sadece Android/ARCore

## İlgili Repo

Backend/parser servisi: [codelens-parser](https://github.com/denizkilinc2/codelens-parser) — repo clone, AST analizi, Kotlin desteği ve LLM enrichment burada gerçekleşiyor.
