#include <QApplication>
#include <QWidget>
#include <QPushButton>
#include <QLineEdit>
#include <QLabel>
#include <QVBoxLayout>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QHostAddress>
#include <QStringList>
#include <QRegularExpression>

bool ipInCidr(const QString& ip, const QString& cidr) {
    // Parse CIDR, e.g., "192.168.1.0/24"
    QRegularExpression re(R"(^([\d\.]+)/(\d+)$)");
    auto match = re.match(cidr);
    if (!match.hasMatch()) return false;

    QHostAddress ip_addr(ip);
    QHostAddress network_addr(match.captured(1));
    int prefix = match.captured(2).toInt();

    if (ip_addr.protocol() != QAbstractSocket::IPv4Protocol || 
        network_addr.protocol() != QAbstractSocket::IPv4Protocol)
        return false;

    quint32 ip_int = ip_addr.toIPv4Address();
    quint32 net_int = network_addr.toIPv4Address();
    quint32 mask = prefix == 0 ? 0 : (~0U << (32 - prefix));

    return (ip_int & mask) == (net_int & mask);
}

class IPChecker : public QWidget {
    Q_OBJECT
public:
    IPChecker(QWidget* parent = nullptr) : QWidget(parent), manager(new QNetworkAccessManager(this)) {
        setWindowTitle("IP in Subnet Checker");

        ipEdit = new QLineEdit(this);
        ipEdit->setPlaceholderText("Enter IP address");

        checkBtn = new QPushButton("Check", this);
        resultLbl = new QLabel("", this);

        auto *layout = new QVBoxLayout(this);
        layout->addWidget(ipEdit);
        layout->addWidget(checkBtn);
        layout->addWidget(resultLbl);

        connect(checkBtn, &QPushButton::clicked, this, &IPChecker::onCheckClicked);
    }

private slots:
    void onCheckClicked() {
        resultLbl->setText("Checking...");
        QString ip = ipEdit->text().trimmed();
        // You may want to validate the IP format here

        // URL to your raw subnet file
        QString url = "https://raw.githubusercontent.com/CompEtcSteve/BlockList/master/ips.txt";
        QNetworkRequest req(QUrl(url));
        QNetworkReply* reply = manager->get(req);

        connect(reply, &QNetworkReply::finished, this, [this, reply, ip]() {
            if (reply->error() != QNetworkReply::NoError) {
                resultLbl->setText("Failed to fetch subnet list.");
                reply->deleteLater();
                return;
            }
            QStringList lines = QString(reply->readAll()).split('\n', Qt::SkipEmptyParts);
            bool found = false;
            for (const QString& subnet : lines) {
                QString s = subnet.trimmed();
                if (s.isEmpty()) continue;
                if (ipInCidr(ip, s)) {
                    resultLbl->setText(ip + " is in subnet " + s);
                    found = true;
                    break;
                }
            }
            if (!found)
                resultLbl->setText(ip + " is not in any of the subnets.");
            reply->deleteLater();
        });
    }

private:
    QLineEdit *ipEdit;
    QPushButton *checkBtn;
    QLabel *resultLbl;
    QNetworkAccessManager *manager;
};

#include "main.moc"

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    IPChecker w;
    w.show();
    return app.exec();
}
