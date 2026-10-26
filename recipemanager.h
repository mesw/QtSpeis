#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <qqmlintegration.h>

class MealPlanManager;

class RecipeManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList recipes READ recipes NOTIFY recipesChanged)
    Q_PROPERTY(QStringList categories READ categories CONSTANT)
    Q_PROPERTY(QVariantList customMealTemplates READ customMealTemplates NOTIFY customMealTemplatesChanged)
    Q_PROPERTY(QVariantList workoutTemplates READ workoutTemplates NOTIFY workoutTemplatesChanged)
    Q_PROPERTY(int recipeCount READ recipeCount CONSTANT)
    Q_PROPERTY(int customTemplateCount READ customTemplateCount NOTIFY customMealTemplatesChanged)

public:
    explicit RecipeManager(QObject *parent = nullptr);

    QVariantList recipes() const { return m_recipes; }
    QStringList categories() const { return m_categories; }
    QVariantList customMealTemplates() const { return m_customMealTemplates; }
    QVariantList workoutTemplates() const { return m_workoutTemplates; }
    int recipeCount() const { return m_recipes.size(); }
    int customTemplateCount() const { return m_customMealTemplates.size(); }

    Q_INVOKABLE QVariantMap getRecipeById(int id) const;
    Q_INVOKABLE QVariantMap getRecipeByIndex(int index) const;

    // Loading recipes into MealPlanManager
    Q_INVOKABLE bool loadRecipeIntoPlan(int recipeId, int servings, const QString &time, QObject *mealPlanManagerObj);

    // Custom meal templates
    Q_INVOKABLE bool saveMealAsTemplate(int mealIndex, const QString &templateName, QObject *mealPlanManagerObj);
    Q_INVOKABLE bool deleteCustomMealTemplate(int templateIndex);
    Q_INVOKABLE bool loadTemplateIntoPlan(int templateIndex, const QString &time, QObject *mealPlanManagerObj);

    // Workouts
    Q_INVOKABLE bool addWorkoutFromPreset(int presetIndex, int durationMinutes, const QString &time, QObject *mealPlanManagerObj);
    Q_INVOKABLE bool saveWorkoutAsTemplate(const QString &title, const QString &type, const QString &time, int durationMinutes,
                                          double calories, double carbs, double protein, double fat);
    Q_INVOKABLE bool deleteWorkoutTemplate(int index);

signals:
    void recipesChanged();
    void customMealTemplatesChanged();
    void workoutTemplatesChanged();

private:
    void loadRecipesFromJson();
    void initCategories();
    void initDefaultWorkouts();
    void loadCustomTemplatesFromSettings();
    void saveCustomTemplatesToSettings();
    void loadWorkoutTemplatesFromSettings();
    void saveWorkoutTemplatesToSettings();

    QVariantList m_recipes;
    QStringList m_categories;
    QVariantList m_customMealTemplates;
    QVariantList m_workoutTemplates;
};
