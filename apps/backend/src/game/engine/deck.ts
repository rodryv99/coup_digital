import { Card } from './types';

export function buildDeck(playerCount: number): Card[] {
  // 3 copias de cada carta hasta 6 jugadores (15), 6 copias de 7 a 12 (30)
  const copies = playerCount <= 6 ? 3 : 6;
  const deck: Card[] = [];
  for (const card of Object.values(Card)) {
    for (let i = 0; i < copies; i++) {
      deck.push(card);
    }
  }
  return shuffle(deck);
}

export function shuffle<T>(array: T[]): T[] {
  const result = [...array];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}