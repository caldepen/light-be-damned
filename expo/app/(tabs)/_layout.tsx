import { Tabs } from "expo-router";
import { Castle, Users, Skull, BombIcon } from "lucide-react-native";
import React from "react";

export default function TabLayout() {
  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: '#d4af37',
        tabBarInactiveTintColor: '#666',
        tabBarStyle: {
          backgroundColor: '#1a1a1a',
          borderTopColor: '#3a3a3a',
        },
        headerStyle: {
          backgroundColor: '#1a1a1a',
        },
        headerTintColor: '#d4af37',
        headerShown: true,
      }}
    >
      <Tabs.Screen
        name="town"
        options={{
          title: "Town",
          tabBarIcon: ({ color }) => <Castle color={color} size={24} />,
        }}
      />
      <Tabs.Screen
        name="inn"
        options={{
          title: "Inn",
          tabBarIcon: ({ color }) => <Users color={color} size={24} />,
        }}
      />
      <Tabs.Screen
        name="catacombs"
        options={{
          title: "Catacombs",
          tabBarIcon: ({ color }) => <Skull color={color} size={24} />,
        }}
      />
      <Tabs.Screen
        name="cemetery"
        options={{
          title: "Cemetery",
          tabBarIcon: ({ color }) => <BombIcon color={color} size={24} />,
        }}
      />
    </Tabs>
  );
}
