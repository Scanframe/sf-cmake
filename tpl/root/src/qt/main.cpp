#include <QApplication>
#include <QDebug>
#include <QPushButton>
#include <hwl/hello.h>
#include <iostream>

int main(int argc, char* argv[])
{
	std::cout << "PATH:" << getenv("PATH") << std::endl;
	QApplication const app(argc, argv);
	QPushButton HelloWorld(
		QString::fromStdString(getHello(0)) + "\nTimestamp: " + QString::fromStdString(utcTimeString()) +
		"\nGCC Version: " + QString::fromStdString(getGCCVersion()) + "\nStandard: " + QString::fromStdString(getCppStandardVersion()) + "\nQt Library: v" +
		qVersion() + "\nQt Build  : v" + QT_VERSION_STR
	);
	HelloWorld.resize(300, 120);
	HelloWorld.show();
	auto rv = QApplication::exec();
#if IS_WIN
	// Need to call exit since the QApplication does not exit normally.
	//std::exit(rv);
	// Kill the other threads so the will not hang.
	killOtherThreads();
#endif
	qInfo() << "Exiting with code:" << rv;
	return rv;
}
