#include "openfoodfactsfetcher.h"
#include "fooddatabase.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrlQuery>
#include <QDebug>
#include <cmath>

OpenFoodFactsFetcher::OpenFoodFactsFetcher(QObject *parent)
    : QObject(parent)
{
}

QNetworkRequest OpenFoodFactsFetcher::createRequest(const QUrl &url)
{
    QNetworkRequest req(url);
#ifndef Q_OS_WASM
    // Open Food Facts requires a descriptive User-Agent on native; on WASM custom User-Agent triggers CORS preflight errors
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("QtSpeisNutritionPlanner - Desktop - Version 1.0 (education-study)"));
#endif
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    return req;
}

QVariantMap OpenFoodFactsFetcher::resolveLocalPresetOrDb(const QString &barcode)
{
    FoodDatabase db;
    db.initDatabase();

    // Check preset barcodes first and enrich from speis.db
    int dbId = 0;
    QString brandName;
    if (barcode == QStringLiteral("4008400404127")) {
        dbId = 1; // Haferflocken / Rolled Oats
        brandName = QStringLiteral("Kölln Flocken Vollkorn-Haferflocken (Rolled Oats)");
    } else if (barcode == QStringLiteral("5201051001078")) {
        dbId = 174; // Griechisches Joghurt 2% / Greek Yogurt
        brandName = QStringLiteral("FAGE Total 2% Greek Strained Yogurt");
    } else if (barcode == QStringLiteral("7610400070776")) {
        dbId = 171; // Dunkle Schokolade / Dark Chocolate
        brandName = QStringLiteral("Lindt Excellence 85% Cocoa Dark Chocolate");
    } else if (barcode == QStringLiteral("0051500241776")) {
        dbId = 169; // Erdnussbutter / Peanut Butter
        brandName = QStringLiteral("Jif Creamy Peanut Butter");
    }

    if (dbId > 0) {
        QVariantMap item = db.getFoodById(dbId);
        if (!item.isEmpty()) {
            item[QStringLiteral("name")] = brandName;
            item[QStringLiteral("barcode")] = barcode;
            return item;
        }
    }

    QVariantMap byBc = db.getFoodByBarcode(barcode);
    if (!byBc.isEmpty()) {
        return byBc;
    }

    return QVariantMap();
}

void OpenFoodFactsFetcher::lookupBarcode(const QString &barcode)
{
    QString trimmed = barcode.trimmed();
    if (trimmed.isEmpty()) {
        emit fetchError(QStringLiteral("Barcode cannot be empty"));
        return;
    }

    // Immediate resolution for built-in test presets or locally cached barcodes
    QVariantMap localMatch = resolveLocalPresetOrDb(trimmed);
    if (!localMatch.isEmpty()) {
        m_isLoading = false;
        m_lastStatus = QStringLiteral("Found product: %1").arg(localMatch.value(QStringLiteral("name")).toString());
        emit loadingChanged();
        emit statusChanged();
        emit barcodeFound(localMatch);
        return;
    }

    m_isLoading = true;
    m_lastStatus = QStringLiteral("Looking up barcode %1...").arg(trimmed);
    emit loadingChanged();
    emit statusChanged();

    QUrl url(QStringLiteral("https://world.openfoodfacts.org/api/v2/product/%1.json").arg(trimmed));
    QNetworkRequest req = createRequest(url);

    QNetworkReply *reply = m_nam.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        handleBarcodeReply(reply);
    });
}

void OpenFoodFactsFetcher::handleBarcodeReply(QNetworkReply *reply)
{
    reply->deleteLater();
    m_isLoading = false;
    emit loadingChanged();

    if (reply->error() != QNetworkReply::NoError) {
        m_lastStatus = QStringLiteral("Network error: %1").arg(reply->errorString());
        emit statusChanged();
        emit fetchError(m_lastStatus);
        return;
    }

    QByteArray data = reply->readAll();
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(data, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        m_lastStatus = QStringLiteral("Invalid response from Open Food Facts");
        emit statusChanged();
        emit fetchError(m_lastStatus);
        return;
    }

    QJsonObject root = doc.object();
    int status = root.value(QStringLiteral("status")).toInt(0);
    if (status != 1) {
        m_lastStatus = QStringLiteral("Product not found in Open Food Facts database");
        emit statusChanged();
        emit fetchError(m_lastStatus);
        return;
    }

    QJsonObject productObj = root.value(QStringLiteral("product")).toObject();
    QVariantMap product = parseProductJson(productObj);

    m_lastStatus = QStringLiteral("Found product: %1").arg(product.value(QStringLiteral("name")).toString());
    emit statusChanged();
    emit barcodeFound(product);
}

void OpenFoodFactsFetcher::search(const QString &query)
{
    QString trimmed = query.trimmed();
    if (trimmed.isEmpty()) {
        emit fetchError(QStringLiteral("Search query cannot be empty"));
        return;
    }

    m_isLoading = true;
    m_lastStatus = QStringLiteral("Searching Open Food Facts for '%1'...").arg(trimmed);
    emit loadingChanged();
    emit statusChanged();

    QUrl url(QStringLiteral("https://world.openfoodfacts.org/cgi/search.pl"));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("search_terms"), trimmed);
    q.addQueryItem(QStringLiteral("search_simple"), QStringLiteral("1"));
    q.addQueryItem(QStringLiteral("action"), QStringLiteral("process"));
    q.addQueryItem(QStringLiteral("json"), QStringLiteral("1"));
    q.addQueryItem(QStringLiteral("page_size"), QStringLiteral("10"));
    url.setQuery(q);

    QNetworkRequest req = createRequest(url);
    QNetworkReply *reply = m_nam.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        handleSearchReply(reply);
    });
}

void OpenFoodFactsFetcher::handleSearchReply(QNetworkReply *reply)
{
    reply->deleteLater();
    m_isLoading = false;
    emit loadingChanged();

    if (reply->error() != QNetworkReply::NoError) {
        m_lastStatus = QStringLiteral("Network search error: %1").arg(reply->errorString());
        emit statusChanged();
        emit fetchError(m_lastStatus);
        return;
    }

    QByteArray data = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) {
        m_lastStatus = QStringLiteral("Invalid search response format");
        emit statusChanged();
        emit fetchError(m_lastStatus);
        return;
    }

    QJsonObject root = doc.object();
    QJsonArray productsArr = root.value(QStringLiteral("products")).toArray();
    QVariantList results;

    for (const auto &val : productsArr) {
        if (val.isObject()) {
            QVariantMap item = parseProductJson(val.toObject());
            if (!item.value(QStringLiteral("name")).toString().isEmpty()) {
                results.append(item);
            }
        }
    }

    m_lastStatus = QStringLiteral("Search returned %1 products").arg(results.size());
    emit statusChanged();
    emit searchCompleted(results);
}

QVariantMap OpenFoodFactsFetcher::parseProductJson(const QJsonObject &obj)
{
    QVariantMap res;
    QString name = obj.value(QStringLiteral("product_name")).toString();
    if (name.isEmpty()) name = obj.value(QStringLiteral("product_name_en")).toString();
    if (name.isEmpty()) name = obj.value(QStringLiteral("generic_name")).toString();
    if (name.isEmpty()) name = QStringLiteral("Unknown Food Item");

    QString brands = obj.value(QStringLiteral("brands")).toString();
    if (!brands.isEmpty() && !name.contains(brands, Qt::CaseInsensitive)) {
        name = brands + QStringLiteral(" ") + name;
    }

    res[QStringLiteral("name")] = name;
    res[QStringLiteral("brands")] = brands;
    res[QStringLiteral("barcode")] = obj.value(QStringLiteral("code")).toString();
    res[QStringLiteral("imageUrl")] = obj.value(QStringLiteral("image_front_small_url")).toString(
        obj.value(QStringLiteral("image_url")).toString()
    );

    QJsonObject nutriments = obj.value(QStringLiteral("nutriments")).toObject();
    double kcal = 0.0;
    if (nutriments.contains(QStringLiteral("energy-kcal_100g"))) {
        kcal = nutriments.value(QStringLiteral("energy-kcal_100g")).toDouble();
    } else if (nutriments.contains(QStringLiteral("energy_100g"))) {
        // Convert kJ to kcal
        kcal = nutriments.value(QStringLiteral("energy_100g")).toDouble() / 4.184;
    }

    double carbs = nutriments.value(QStringLiteral("carbohydrates_100g")).toDouble(0.0);
    double protein = nutriments.value(QStringLiteral("proteins_100g")).toDouble(0.0);
    double fat = nutriments.value(QStringLiteral("fat_100g")).toDouble(0.0);
    double fiber = nutriments.value(QStringLiteral("fiber_100g")).toDouble(0.0);
    double satFat = nutriments.value(QStringLiteral("saturated-fat_100g")).toDouble(0.0);
    double mufa = nutriments.value(QStringLiteral("monounsaturated-fat_100g")).toDouble(0.0);
    double pufa = nutriments.value(QStringLiteral("polyunsaturated-fat_100g")).toDouble(0.0);
    double omega3 = nutriments.value(QStringLiteral("omega-3-fat_100g")).toDouble(0.0);
    double omega6 = nutriments.value(QStringLiteral("omega-6-fat_100g")).toDouble(0.0);

    // OpenFoodFacts stores minerals in g per 100g (or mg if *_unit is mg); convert g -> mg if < 10
    auto getMg = [&](const QString &key) -> double {
        if (!nutriments.contains(key)) return 0.0;
        double v = nutriments.value(key).toDouble(0.0);
        QString u = nutriments.value(key + QStringLiteral("_unit")).toString().toLower();
        if (u == QStringLiteral("g") || (u.isEmpty() && v > 0.0 && v < 5.0)) {
            return v * 1000.0;
        }
        return v;
    };

    res[QStringLiteral("calories")] = std::round(kcal * 10.0) / 10.0;
    res[QStringLiteral("carbs")] = std::round(carbs * 10.0) / 10.0;
    res[QStringLiteral("protein")] = std::round(protein * 10.0) / 10.0;
    res[QStringLiteral("fat")] = std::round(fat * 10.0) / 10.0;
    res[QStringLiteral("fiber")] = std::round(fiber * 10.0) / 10.0;
    res[QStringLiteral("satFat")] = std::round(satFat * 100.0) / 100.0;
    res[QStringLiteral("mufa")] = std::round(mufa * 100.0) / 100.0;
    res[QStringLiteral("pufa")] = std::round(pufa * 100.0) / 100.0;
    res[QStringLiteral("omega3")] = std::round(omega3 * 100.0) / 100.0;
    res[QStringLiteral("omega6")] = std::round(omega6 * 100.0) / 100.0;
    res[QStringLiteral("calcium")] = std::round(getMg(QStringLiteral("calcium_100g")) * 10.0) / 10.0;
    res[QStringLiteral("iron")] = std::round(getMg(QStringLiteral("iron_100g")) * 100.0) / 100.0;
    res[QStringLiteral("zinc")] = std::round(getMg(QStringLiteral("zinc_100g")) * 100.0) / 100.0;
    res[QStringLiteral("copper")] = std::round(getMg(QStringLiteral("copper_100g")) * 100.0) / 100.0;
    res[QStringLiteral("magnesium")] = std::round(getMg(QStringLiteral("magnesium_100g")) * 10.0) / 10.0;
    res[QStringLiteral("potassium")] = std::round(getMg(QStringLiteral("potassium_100g")) * 10.0) / 10.0;
    res[QStringLiteral("sodium")] = std::round(getMg(QStringLiteral("sodium_100g")) * 10.0) / 10.0;
    res[QStringLiteral("vitaminC")] = std::round(getMg(QStringLiteral("vitamin-c_100g")) * 10.0) / 10.0;
    res[QStringLiteral("servingSize")] = 100.0;
    res[QStringLiteral("servingUnit")] = QStringLiteral("g");
    res[QStringLiteral("category")] = QStringLiteral("Packaged Food");
    res[QStringLiteral("icon")] = QStringLiteral("🏷️");
    res[QStringLiteral("ingredients")] = obj.value(QStringLiteral("ingredients_text")).toString();

    return res;
}
