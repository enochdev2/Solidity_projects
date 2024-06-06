use anchor_lang::prelude::*;
use anchor_lang::solana_program::system_program;

declare_id!("YourProgramIDHere"); // Replace with your actual program ID

#[program]
pub mod transact {
    use super::*;

    pub fn add_to_blockchain(ctx: Context<AddToBlockchain>, amount: u64, message: String, keyword: String) -> ProgramResult {
        let transaction = &mut ctx.accounts.transaction;
        let transaction_count = &mut ctx.accounts.transaction_count;

        transaction.sender = *ctx.accounts.sender.key;
        transaction.receiver = *ctx.accounts.receiver.key;
        transaction.amount = amount;
        transaction.message = message;
        transaction.timestamp = Clock::get().unwrap().unix_timestamp;
        transaction.keyword = keyword;

        transaction_count.count += 1;
        emit!(Transfer {
            from: transaction.sender,
            receiver: transaction.receiver,
            amount: transaction.amount,
            message: transaction.message.clone(),
            timestamp: transaction.timestamp,
            keyword: transaction.keyword.clone()
        });

        Ok(())
    }

    pub fn get_all_transactions(ctx: Context<GetAllTransactions>) -> Vec<TransferStruct> {
        ctx.accounts.transaction_history.to_vec()
    }

    pub fn get_transaction_count(ctx: Context<GetTransactionCount>) -> u64 {
        ctx.accounts.transaction_count.count
    }
}

#[derive(Accounts)]
pub struct AddToBlockchain<'info> {
    #[account(init, payer = sender, space = 8 + 32 + 32 + 8 + 4 + 8 + 4)]
    pub transaction: Account<'info, TransferStruct>,
    #[account(mut)]
    pub transaction_count: Account<'info, TransactionCount>,
    #[account(mut)]
    pub sender: Signer<'info>,
    pub receiver: SystemAccount<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct GetAllTransactions<'info> {
    pub transaction_history: Account<'info, TransactionHistory>,
}

#[derive(Accounts)]
pub struct GetTransactionCount<'info> {
    pub transaction_count: Account<'info, TransactionCount>,
}

#[account]
pub struct TransferStruct {
    pub sender: Pubkey,
    pub receiver: Pubkey,
    pub amount: u64,
    pub message: String,
    pub timestamp: i64,
    pub keyword: String,
}

#[account]
pub struct TransactionCount {
    pub count: u64,
}

#[account]
pub struct TransactionHistory {
    pub transactions: Vec<TransferStruct>,
}

#[event]
pub struct Transfer {
    pub from: Pubkey,
    pub receiver: Pubkey,
    pub amount: u64,
    pub message: String,
    pub timestamp: i64,
    pub keyword: String,
}
