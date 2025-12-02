# XCFramework Generator App

A very simple macOS utility that turns a iOS `.xcodeproj` into a distributable iOS `.xcframework`.

![](/app.png)

## Highlights

- Drag-and-drop project selection with scheme awareness
- Guided build steps with real-time logs and linear progress indicators

## Requirements

- macOS 14.4+
- Xcode 16+
- Swift 5.9+

## Getting Started

1. Clone the repository and open `XCFrameworkGeneratorApp.xcodeproj` in Xcode.
2. Select the **XCFrameworkGeneratorApp** scheme and run the app.
3. Use the *Open Project* button (or drop an `.xcodeproj`) to load your project.
4. Pick any shared scheme and hit *Generate XCFramework*.
5. Once successful, the app reveals the generated `.xcframework` in Finder.

## License

This project is available under the [MIT License](LICENSE).
