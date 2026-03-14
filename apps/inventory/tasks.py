import logging
import random

from celery import shared_task
from django.db import transaction

logger = logging.getLogger(__name__)

# Rarity weights by placement role
# Winner gets better odds for rarer items; loser gets heavier common weighting
WINNER_RARITY_WEIGHTS = {
    'common': 30,
    'uncommon': 40,
    'rare': 20,
    'epic': 8,
    'legendary': 2,
}

LOSER_RARITY_WEIGHTS = {
    'common': 50,
    'uncommon': 30,
    'rare': 15,
    'epic': 4,
    'legendary': 1,
}

# Excluded item types from random drops (crates, keys, and cosmetics are not rewarded this way)
_EXCLUDED_TYPES = {
    'crate',
    'key',
    'cosmetic',
}


def generate_match_drops(match_id: str):
    """Generate item drops for all players after a match finishes.

    Called from finalize_match_results_sync inside apps/game/tasks.py.

    Winner (placement=1): 50 gold + 2-4 random item drops (winner rarity weights).
    Loser (placement>1): 20 gold + 1-2 random item drops (loser rarity weights).

    Drop pool: active Item objects excluding crate, key, and cosmetic types.
    Creates ItemDrop records with source='match_reward' and match FK.
    Adds items to UserInventory and gold to Wallet.
    """
    from apps.game.models import PlayerResult
    from apps.inventory.models import Item, ItemDrop, UserInventory, Wallet

    player_results = list(
        PlayerResult.objects
        .filter(match_result__match_id=match_id)
        .select_related('user', 'match_result__match')
    )

    if not player_results:
        logger.warning("No player results found for match %s, skipping drops", match_id)
        return

    # Fetch all droppable items (exclude crate, key, cosmetic)
    droppable_items = list(
        Item.objects.filter(is_active=True)
        .exclude(item_type__in=list(_EXCLUDED_TYPES))
    )

    if not droppable_items:
        logger.warning("No droppable items defined, skipping drops for match %s", match_id)
        return

    # Group droppable items by rarity for weighted selection
    items_by_rarity: dict[str, list] = {}
    for item in droppable_items:
        items_by_rarity.setdefault(item.rarity, []).append(item)

    # All rarities available in the pool (for fallback)
    all_rarities = list(items_by_rarity.keys())

    match_obj = player_results[0].match_result.match

    for pr in player_results:
        if pr.user.is_bot:
            continue

        is_winner = pr.placement == 1
        gold_reward = 50 if is_winner else 20
        min_drops = 2 if is_winner else 1
        max_drops = 4 if is_winner else 2
        rarity_weights = WINNER_RARITY_WEIGHTS if is_winner else LOSER_RARITY_WEIGHTS

        with transaction.atomic():
            # Add gold to wallet
            wallet, _ = Wallet.objects.get_or_create(user=pr.user)
            wallet.gold += gold_reward
            wallet.total_earned += gold_reward
            wallet.save(update_fields=['gold', 'total_earned'])

            # Roll item drops
            num_drops = random.randint(min_drops, max_drops)
            for _ in range(num_drops):
                rarity = _roll_rarity(rarity_weights, all_rarities)
                pool = items_by_rarity.get(rarity)
                if not pool:
                    # Fallback to any rarity present in pool
                    pool = droppable_items
                drop_item = random.choice(pool)

                # Add to inventory
                inv, created = UserInventory.objects.get_or_create(
                    user=pr.user, item=drop_item,
                    defaults={'quantity': 1},
                )
                if not created:
                    inv.quantity = min(inv.quantity + 1, drop_item.max_stack)
                    inv.save(update_fields=['quantity'])

                # Record the drop
                ItemDrop.objects.create(
                    user=pr.user,
                    item=drop_item,
                    quantity=1,
                    source=ItemDrop.DropSource.MATCH_REWARD,
                    match=match_obj,
                )

    logger.info(
        "Generated drops for %d human players in match %s",
        sum(1 for pr in player_results if not pr.user.is_bot),
        match_id,
    )


def _roll_rarity(weights: dict[str, int], available_rarities: list[str]) -> str:
    """Roll a rarity string from the given weight table, restricted to available rarities."""
    # Filter weights to only rarities that have items in the pool
    filtered = {r: w for r, w in weights.items() if r in available_rarities}
    if not filtered:
        # Last resort: pick any available rarity uniformly
        return random.choice(available_rarities)
    rarities = list(filtered.keys())
    rarity_weights = list(filtered.values())
    return random.choices(rarities, weights=rarity_weights, k=1)[0]


@shared_task
def generate_match_drops_task(match_id: str):
    """Celery wrapper for post-match drop generation."""
    generate_match_drops(match_id)
