import { Link, Stack } from "expo-router";
import { StyleSheet, Text, View } from "react-native";

export default function NotFoundScreen() {
  return (
    <>
      <Stack.Screen options={{ title: "Lost in the Catacombs" }} />
      <View style={styles.container}>
        <Text style={styles.title}>You&apos;ve wandered into darkness...</Text>
        <Text style={styles.subtitle}>This path doesn&apos;t exist.</Text>

        <Link href="/(tabs)/town" style={styles.link}>
          <Text style={styles.linkText}>Return to Town</Text>
        </Link>
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    padding: 20,
    backgroundColor: '#0a0a0a',
  },
  title: {
    fontSize: 24,
    fontWeight: "bold" as const,
    color: '#d4af37',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 16,
    color: '#aaa',
    marginBottom: 24,
  },
  link: {
    marginTop: 15,
    paddingVertical: 15,
    paddingHorizontal: 32,
    backgroundColor: '#d4af37',
    borderRadius: 8,
  },
  linkText: {
    fontSize: 16,
    color: "#1a1a1a",
    fontWeight: 'bold' as const,
  },
});
