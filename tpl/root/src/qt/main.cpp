#include <QApplication>
#include <QPushButton>
#include <hwl/hello.h>

int main(int argc, char* argv[])
{
	auto app = new QApplication(argc, argv);
	QPushButton HelloWorld(
		QString::fromStdString(getHello(0)) + "\nTimestamp: " + QString::fromStdString(utcTimeString()) +
		QString("\nQemu Virtualization: ").append(isQemu() ? "Yes" : "No") + QString("\nWine Compatibility Layer: ").append(isWine() ? "Yes" : "No") +
		"\nCPU Architecture: " + QString::fromStdString(getCpuArchitecture()) + "\nGCC Version: " + QString::fromStdString(getGCCVersion()) +
		"\nStandard: " + QString::fromStdString(getCppStandardVersion()) + "\nQt Library: v" + qVersion() + "\nQt Build  : v" + QT_VERSION_STR
	);
	HelloWorld.resize(300, 150);
	HelloWorld.show();
	auto rv = app->exec();
	// Fix for hanging Qt threads in Wine since 6.9.1
	#if QT_VERSION >= QT_VERSION_CHECK(6, 9, 0)
	killOtherThreads();
	#endif
	delete app;
	return rv;
}