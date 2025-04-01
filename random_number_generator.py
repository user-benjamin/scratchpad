import random
import argparse

def generate_random_number(min_val=1, max_val=100):
    """Generate a random number between min_val and max_val (inclusive)."""
    return random.randint(min_val, max_val)

def main():
    parser = argparse.ArgumentParser(description='Generate random numbers.')
    parser.add_argument('--min', type=int, default=1, help='Minimum value (default: 1)')
    parser.add_argument('--max', type=int, default=100, help='Maximum value (default: 100)')
    parser.add_argument('--count', type=int, default=1, help='Number of random numbers to generate (default: 1)')
    
    args = parser.parse_args()
    
    print(f"Generating {args.count} random number(s) between {args.min} and {args.max}:")
    
    for i in range(args.count):
        number = generate_random_number(args.min, args.max)
        print(f"Random number {i+1}: {number}")

if __name__ == "__main__":
    main()
