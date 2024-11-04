# ESKit

ESKitは、イベントソーシング用ライブラリです。

<p align="center">
    <a href="https://github.com/lemo-nade-room/es-kit/actions/workflows/swift-ci.yaml">
        <img src="https://github.com/lemo-nade-room/es-kit/actions/workflows/swift-ci.yaml/badge.svg" alt="Testing Status">
    </a>
    <a href="https://lemo-nade-room.github.io/es-kit/">
        <img src="https://design.vapor.codes/images/readthedocs.svg" alt="Documentation">
    </a>
    <a href="LICENSE">
        <img src="https://design.vapor.codes/images/mitlicense.svg" alt="MIT License">
    </a>
</p>

## 特徴

- 集約とそれに対応するイベントプロトコルの定義
- RDBを用いたイベントのリプレイと記録
- スナップショットによる集約のリプレイの高速化

## サポート

- macOS >= 14
- Swift > 6.0.0

## インストール

ESKitをプロジェクトに追加するには、Swift Package Managerを使用します。`Package.swift`に以下の依存関係を追加してください。

```swift
dependencies: [
    .package(url: "https://github.com/lemo-nade-room/es-kit.git", branch: "main")
]
```

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "ESKit", package: "es-kit"),
        .product(name: "ESKitFluentSQLDatabaseDriver", package: "es-kit"),
    ]
),
```

## ライセンス

このライブラリはMITライセンスで提供されています。詳細は[LICENSE](./LICENSE)ファイルをご覧ください。