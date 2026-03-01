# Code generieren (Drift)
gen:
    dart run build_runner build --delete-conflicting-outputs

# Kontinuierlich generieren
gen-watch:
    dart run build_runner watch --delete-conflicting-outputs

test:
    flutter test

lint:
    flutter analyze

apk:
    flutter build apk

release:
    flutter build apk --release

run:
    flutter run

install:
    flutter pub get

clean:
    flutter clean
    dart run build_runner clean
