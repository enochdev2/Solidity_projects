use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer};
use std::collections::HashMap;

declare_id!("Fg6S..."); // Replace with your actual program ID

#[program]
pub mod custom_dex {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>, tokens: Vec<String>) -> ProgramResult {
        let dex_account = &mut ctx.accounts.dex_account;
        dex_account.token_list = tokens;
        dex_account.history_index = 0;
        Ok(())
    }

    // Define other functions such as get_balance, swap, etc.
}

#[derive(Accounts)]
pub struct Initialize {
    #[account(
        init, 
        payer = user, 
        space = 8 + 64 + 64 + (32 * 8))]
    pub dex_account: Account<'info, DexAccount>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[account]
pub struct DexAccount {
    pub token_list: Vec<String>,
    pub history_index: u64,
    // Consider using a more complex data structure for history and tokenInstanceMap
}

// Define other structs and implementations here



use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount};
use std::collections::HashMap;

// ... other code ...

#[derive(Accounts)]
pub struct GetBalance<'info> {
    #[account()]
    pub token_account: Account<'info, TokenAccount>,
}

#[derive(Accounts)]
pub struct GetTokenInfo<'info> {
    #[account()]
    pub mint: Account<'info, Mint>,
}

// ... other code ...

impl<'info> GetBalance<'info> {
    pub fn get_balance(&self) -> u64 {
        self.token_account.amount
    }
}

impl<'info> GetTokenInfo<'info> {
    pub fn get_total_supply(&self) -> u64 {
        self.mint.supply
    }

    pub fn get_name(&self) -> String {
        // Token names are not stored on-chain in Solana. You would need to manage this off-chain.
        "Token name not available on-chain".to_string()
    }
}

// ... other code ...

