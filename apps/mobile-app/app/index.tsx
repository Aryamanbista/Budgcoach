import { useEffect, useState } from "react";
import {
  ActivityIndicator,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import { forecastBudget, predictCategory } from "../src/services/api";

export default function HomeScreen() {
  const [categoryResult, setCategoryResult] = useState<string | null>(null);
  const [forecastResult, setForecastResult] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function runDemo() {
    setLoading(true);
    setCategoryResult(null);
    setForecastResult(null);
    try {
      const category = await predictCategory("FT-123-KHALTI-MOMO");
      setCategoryResult(
        `Category: ${category.category} (confidence: ${category.confidence}) — mock: ${category.is_mock}`,
      );

      const forecast = await forecastBudget([
        { date: "2024-03-01", amount: 350 },
        { date: "2024-03-02", amount: 180 },
        { date: "2024-03-03", amount: 500 },
      ]);
      setForecastResult(
        `Predicted spend: NPR ${forecast.predicted_spend} | Breach warning: ${forecast.budget_breach_warning} | Days until breach: ${forecast.days_until_breach}`,
      );
    } catch (error) {
      setCategoryResult(`Error: ${String(error)}`);
    } finally {
      setLoading(false);
    }
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>💰 Budgcoach</Text>
      <Text style={styles.subtitle}>
        AI-driven budget optimizer for Nepalese youth.{"\n"}
        Combating <Text style={styles.accent}>Spendception</Text> — one
        transaction at a time.
      </Text>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>ML Engine Demo</Text>
        <Text style={styles.cardBody}>
          Tap the button below to call the FastAPI dummy endpoints and see the
          API contract in action.
        </Text>
        <TouchableOpacity style={styles.button} onPress={runDemo} disabled={loading}>
          {loading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.buttonText}>Run API Demo</Text>
          )}
        </TouchableOpacity>
        {categoryResult && (
          <Text style={styles.result}>{categoryResult}</Text>
        )}
        {forecastResult && (
          <Text style={styles.result}>{forecastResult}</Text>
        )}
      </View>

      <View style={styles.infoRow}>
        <View style={styles.badge}>
          <Text style={styles.badgeLabel}>Backend</Text>
          <Text style={styles.badgeValue}>FastAPI</Text>
        </View>
        <View style={styles.badge}>
          <Text style={styles.badgeLabel}>Database</Text>
          <Text style={styles.badgeValue}>Supabase</Text>
        </View>
        <View style={styles.badge}>
          <Text style={styles.badgeLabel}>OCR</Text>
          <Text style={styles.badgeValue}>Tesseract</Text>
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flexGrow: 1,
    backgroundColor: "#EEF2FF",
    alignItems: "center",
    padding: 24,
    paddingTop: 60,
  },
  title: {
    fontSize: 32,
    fontWeight: "bold",
    color: "#4338CA",
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 15,
    color: "#6B7280",
    textAlign: "center",
    marginBottom: 32,
    lineHeight: 22,
  },
  accent: {
    fontWeight: "600",
    color: "#6366F1",
  },
  card: {
    backgroundColor: "#fff",
    borderRadius: 16,
    padding: 20,
    width: "100%",
    shadowColor: "#000",
    shadowOpacity: 0.08,
    shadowRadius: 12,
    elevation: 3,
    marginBottom: 24,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: "700",
    color: "#1F2937",
    marginBottom: 8,
  },
  cardBody: {
    fontSize: 14,
    color: "#6B7280",
    marginBottom: 16,
    lineHeight: 20,
  },
  button: {
    backgroundColor: "#4F46E5",
    paddingVertical: 12,
    borderRadius: 10,
    alignItems: "center",
  },
  buttonText: {
    color: "#fff",
    fontWeight: "600",
    fontSize: 15,
  },
  result: {
    marginTop: 12,
    fontSize: 13,
    color: "#374151",
    backgroundColor: "#F9FAFB",
    borderRadius: 8,
    padding: 10,
    lineHeight: 18,
  },
  infoRow: {
    flexDirection: "row",
    gap: 10,
  },
  badge: {
    flex: 1,
    backgroundColor: "#fff",
    borderRadius: 12,
    padding: 12,
    alignItems: "center",
    shadowColor: "#000",
    shadowOpacity: 0.05,
    shadowRadius: 6,
    elevation: 2,
  },
  badgeLabel: {
    fontSize: 10,
    color: "#9CA3AF",
    textTransform: "uppercase",
    letterSpacing: 0.5,
    marginBottom: 4,
  },
  badgeValue: {
    fontSize: 13,
    fontWeight: "600",
    color: "#374151",
  },
});
