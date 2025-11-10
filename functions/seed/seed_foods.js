/**
 * Seed script to populate Firestore with Vietnamese foods using firebase-admin.
 * Usage:
 *   npm install
 *   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
 *   node seed_foods.js
 *
 * To target the local emulator pass --emulator
 *   firebase emulators:start --only firestore
 *   node seed_foods.js --emulator
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const useEmulator = process.argv.includes('--emulator');

if (useEmulator) {
  console.log('Using Firestore emulator at localhost:8080');
  process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
}

if (!admin.apps.length) {
  try {
    admin.initializeApp();
  } catch (e) {
    console.error('Failed to initialize admin SDK:', e.message);
    process.exit(1);
  }
}

const firestore = admin.firestore();

const foods = [
  { id: 'pho', name: 'Phở bò', kcal_per_100g: 120, protein_g: 7, carb_g: 10, fat_g: 4, tags: ['soup', 'beef'], imageUrl: '' },
  { id: 'buncha', name: 'Bún chả', kcal_per_100g: 210, protein_g: 10, carb_g: 20, fat_g: 10, tags: ['grill'], imageUrl: '' },
  { id: 'banhmi', name: 'Bánh mì', kcal_per_100g: 260, protein_g: 8, carb_g: 45, fat_g: 6, tags: ['bread'], imageUrl: '' },
  { id: 'comtam', name: 'Cơm tấm', kcal_per_100g: 200, protein_g: 7, carb_g: 40, fat_g: 3, tags: ['rice'], imageUrl: '' },
  { id: 'goicuon', name: 'Gỏi cuốn', kcal_per_100g: 95, protein_g: 3, carb_g: 12, fat_g: 2, tags: ['fresh'], imageUrl: '' },
  { id: 'bunbo', name: 'Bún bò Huế', kcal_per_100g: 150, protein_g: 8, carb_g: 18, fat_g: 5, tags: ['soup'], imageUrl: '' },
  { id: 'chaoluc', name: 'Cháo lòng', kcal_per_100g: 85, protein_g: 6, carb_g: 12, fat_g: 1, tags: ['porridge'], imageUrl: '' },
  { id: 'ca', name: 'Cá kho', kcal_per_100g: 180, protein_g: 20, carb_g: 0, fat_g: 10, tags: ['fish'], imageUrl: '' },
  { id: 'ga', name: 'Gà luộc', kcal_per_100g: 165, protein_g: 31, carb_g: 0, fat_g: 4, tags: ['chicken'], imageUrl: '' },
  { id: 'cha', name: 'Chả giò', kcal_per_100g: 250, protein_g: 6, carb_g: 30, fat_g: 10, tags: ['fried'], imageUrl: '' },
  { id: 'xoi', name: 'Xôi', kcal_per_100g: 200, protein_g: 5, carb_g: 45, fat_g: 2, tags: ['rice'], imageUrl: '' },
  { id: 'bunthitnuong', name: 'Bún thịt nướng', kcal_per_100g: 230, protein_g: 9, carb_g: 28, fat_g: 8, tags: ['grill'], imageUrl: '' },
  { id: 'canh', name: 'Canh chua', kcal_per_100g: 40, protein_g: 2, carb_g: 6, fat_g: 1, tags: ['soup'], imageUrl: '' },
  { id: 'nem', name: 'Nem rán', kcal_per_100g: 240, protein_g: 7, carb_g: 28, fat_g: 9, tags: ['fried'], imageUrl: '' },
  { id: 'bot', name: 'Bột chiên', kcal_per_100g: 260, protein_g: 6, carb_g: 33, fat_g: 11, tags: ['street'], imageUrl: '' },
  { id: 'che', name: 'Chè', kcal_per_100g: 150, protein_g: 2, carb_g: 30, fat_g: 2, tags: ['dessert'], imageUrl: '' },
  { id: 'banhcuon', name: 'Bánh cuốn', kcal_per_100g: 140, protein_g: 4, carb_g: 22, fat_g: 3, tags: ['rice'], imageUrl: '' },
  { id: 'banhxeo', name: 'Bánh xèo', kcal_per_100g: 270, protein_g: 8, carb_g: 28, fat_g: 12, tags: ['pan'], imageUrl: '' },
  { id: 'rau', name: 'Rau luộc', kcal_per_100g: 25, protein_g: 2, carb_g: 5, fat_g: 0, tags: ['veg'], imageUrl: '' },
  { id: 'mut', name: 'Mứt', kcal_per_100g: 300, protein_g: 0, carb_g: 75, fat_g: 0, tags: ['sweet'], imageUrl: '' },
  { id: 'sua', name: 'Sữa chua', kcal_per_100g: 60, protein_g: 3, carb_g: 8, fat_g: 1, tags: ['dairy'], imageUrl: '' },
  { id: 'thitbo', name: 'Thịt bò', kcal_per_100g: 250, protein_g: 26, carb_g: 0, fat_g: 15, tags: ['beef'], imageUrl: '' },
  { id: 'thitheo', name: 'Thịt heo', kcal_per_100g: 242, protein_g: 25, carb_g: 0, fat_g: 14, tags: ['pork'], imageUrl: '' },
  { id: 'dua', name: 'Dưa leo', kcal_per_100g: 15, protein_g: 0.7, carb_g: 3, fat_g: 0, tags: ['veg'], imageUrl: '' },
  { id: 'trung', name: 'Trứng luộc', kcal_per_100g: 155, protein_g: 13, carb_g: 1, fat_g: 11, tags: ['egg'], imageUrl: '' },
  { id: 'sushi', name: 'Sushi (viet style)', kcal_per_100g: 130, protein_g: 5, carb_g: 20, fat_g: 2, tags: ['rice'], imageUrl: '' },
  { id: 'muc', name: 'Mực nướng', kcal_per_100g: 95, protein_g: 15, carb_g: 1, fat_g: 2, tags: ['seafood'], imageUrl: '' },
  { id: 'tom', name: 'Tôm', kcal_per_100g: 99, protein_g: 24, carb_g: 0, fat_g: 0.3, tags: ['seafood'], imageUrl: '' },
];

async function upsertFood(food) {
  const ref = firestore.collection('foods').doc(food.id);
  await ref.set({
    ...food,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

async function main() {
  for (const f of foods) {
    console.log('Seeding', f.id);
    await upsertFood(f);
  }
  console.log('Seeding complete');
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
