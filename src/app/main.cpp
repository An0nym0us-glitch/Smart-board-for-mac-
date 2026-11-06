#include "app/AppSettings.h"
#include "app/MainWindow.h"
#include "ui/UiContext.h"

#include <QApplication>
#include <QCommandLineParser>
#include <QFileOpenEvent>
#include <QIcon>
#include <QPointer>
#include <QTimer>

namespace {
/// macOS hands files opened from Finder (double-click, "Open With", dropping on the Dock
/// icon) to the running application as QFileOpenEvent instead of command line arguments.
class FileOpenHandler : public QObject
{
public:
    explicit FileOpenHandler(cb::MainWindow& window)
        : m_window(&window)
    {
    }

protected:
    bool eventFilter(QObject* watched, QEvent* event) override
    {
        if (event->type() == QEvent::FileOpen && m_window) {
            const QString path = static_cast<QFileOpenEvent*>(event)->file();
            if (!path.isEmpty()) {
                m_window->openFiles({path});
                m_window->raise();
                m_window->activateWindow();
            }
            return true;
        }
        return QObject::eventFilter(watched, event);
    }

private:
    QPointer<cb::MainWindow> m_window;
};
} // namespace

int main(int argc, char* argv[])
{
    // DPI awareness: crisp rendering on 1080p, 1440p and 4K, including fractional Windows
    // scaling (macOS Retina displays are handled by Qt automatically).
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QCoreApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);

    QApplication app(argc, argv);
    QApplication::setApplicationName(QStringLiteral("ClassBoard"));
    QApplication::setOrganizationName(QStringLiteral("ClassBoard"));
    QApplication::setApplicationVersion(QStringLiteral(CLASSBOARD_VERSION));
#ifndef Q_OS_MACOS
    // On macOS the Dock and Finder use the bundle's classboard.icns.
    QApplication::setWindowIcon(QIcon(QStringLiteral(":/app/classboard.svg")));
#endif
    Q_INIT_RESOURCE(classboard);

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("ClassBoard - digital classroom board"));
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addPositionalArgument(QStringLiteral("lesson"), QStringLiteral("Lesson (.classboard) to open."));
    QCommandLineOption screenshot(QStringLiteral("screenshot"),
                                  QStringLiteral("Render the window to an image after start-up and exit (diagnostics)."),
                                  QStringLiteral("file"));
    QCommandLineOption scale(QStringLiteral("ui-scale"), QStringLiteral("Override the interface size (e.g. 1.5)."),
                             QStringLiteral("factor"));
    parser.addOption(screenshot);
    parser.addOption(scale);
    parser.process(app);

    cb::UiContext ui;
    ui.theme.load(QStringLiteral(":/themes/dark.json"));
    cb::AppSettings settings;
    if (parser.isSet(scale))
        settings.setUiScale(parser.value(scale).toDouble());

    cb::MainWindow window(ui, settings);
    FileOpenHandler fileOpen(window);
    app.installEventFilter(&fileOpen);
    window.show();
    const QStringList args = parser.positionalArguments();
    window.startup(args.isEmpty() ? QString() : args.first());

    if (parser.isSet(screenshot)) {
        const QString path = parser.value(screenshot);
        QTimer::singleShot(1500, &window, [&window, path]() {
            window.grab().save(path);
            QCoreApplication::quit();
        });
    }
    return app.exec();
}
