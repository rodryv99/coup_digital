import { Card, ActionType } from './types';

export const ACTION_REQUIRED_CARD: Partial<Record<ActionType, Card>> = {
  [ActionType.Tax]: Card.Duke,
  [ActionType.Assassinate]: Card.Assassin,
  [ActionType.Steal]: Card.Captain,
  [ActionType.Exchange]: Card.Ambassador,
};

export const BLOCKABLE_BY: Partial<Record<ActionType, Card[]>> = {
  [ActionType.ForeignAid]: [Card.Duke],
  [ActionType.Assassinate]: [Card.Contessa],
  [ActionType.Steal]: [Card.Captain, Card.Ambassador],
};

export function canBeChallenged(action: ActionType): boolean {
  return action in ACTION_REQUIRED_CARD;
}

export function canBeBlocked(action: ActionType): boolean {
  return action in BLOCKABLE_BY;
}

export function isValidBlockCard(action: ActionType, card: Card): boolean {
  const blockers = BLOCKABLE_BY[action];
  return !!blockers && blockers.includes(card);
}