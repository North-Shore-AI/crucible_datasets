# Tinker Cookbook Requirements

This is the concrete requirement set derived from tinker-cookbook usage. It is the
minimum compatibility target for tinkex_cookbook.

## Datasets Used
| Domain | HF repo id | Splits / config | Format | Required features | Elixir status |
| --- | --- | --- | --- | --- | --- |
| Math | openai/gsm8k | split=train,test; name=main | JSONL | answer extraction | Implemented; wired to HF |
| Math | HuggingFaceH4/MATH-500 | split=test; name=default | Parquet | boxed answer parsing | Implemented; wired to HF |
| Math | EleutherAI/hendrycks_math | split=train/test; name=subject | Parquet | config enumeration | Implemented; repo id fixed |
| Math | zwhe99/DeepMath-103K | split=train | Parquet | large dataset | Implemented; repo id fixed |
| Math | POLARIS-Project/Polaris-Dataset-53K | split=train | Parquet | large dataset | Implemented; repo id fixed |
| Chat | allenai/tulu-3-sft-mixture | split=train | Parquet | messages/conversation | Implemented; wired to HF |
| Chat | HuggingFaceH4/no_robots | split=train/test | Parquet | messages/conversation | Implemented; wired to HF |
| Preference | Anthropic/hh-rlhf | split=train/test | Parquet | chosen/rejected parsing | Implemented; wired to HF |
| Preference | nvidia/HelpSteer3 | config=preference | Parquet | response_a/b + label | Implemented; config handled |
| Preference | nvidia/HelpSteer2 | split=train | Parquet | single response + scores | Implemented; wired to HF |
| Preference | argilla/ultrafeedback-binarized-preferences | split=train | Parquet | ranked responses | Implemented; repo id fixed |
| Preference | lmarena-ai/arena-human-preference-140k | split=train | Parquet | prompt + answer_a/b + winner | Implemented; repo id fixed |
| Preference | allenai/llama-3.1-tulu-3-8b-preference-mixture | split=train | Parquet | chosen/rejected | Implemented; repo id fixed |
| Code | agentica-org/DeepCoder-Preview-Dataset | split=train/test; name=primeintellect,taco,lcbv5,codeforces | Parquet | config enumeration | Implemented; config handled |
| Reasoning | open-thoughts/OpenThoughts3-1.2M | split=train; streaming=True | Parquet | streaming | Implemented; streaming via `load_dataset` |
| Rubric | prometheus-eval/Feedback-Collection | split=train | Parquet/JSONL | rubric parsing | Implemented |
| Vision | dpdl-benchmark/caltech101 | split=train/test | Parquet + images | image feature | Implemented; Image feature + decode |
| Vision | dpdl-benchmark/oxford_flowers102 | split=train/test | Parquet + images | image feature | Implemented; Image feature + decode |
| Vision | dpdl-benchmark/oxford_iiit_pet | split=train/test | Parquet + images | image feature | Implemented; Image feature + decode |
| Vision | tanganke/stanford_cars | split=train/test | Parquet + images | image feature | Implemented; Image feature + decode |

## Operations Used
- datasets.load_dataset(name, config, split)
- datasets.load_dataset(..., streaming=True) for OpenThoughts
- get_dataset_config_names(name)
- dataset["train"] / dataset["test"] on DatasetDict
- .shuffle(seed)
- .filter(fn)
- .select(range)
- .take(n) / .skip(n)
- .map(transform_fn)
- .batch(batch_size, drop_last_batch=True)
- concatenate_datasets([ds1, ds2, ...])
- Dataset.from_list(list)
- Dataset.from_pandas(df)

## Shape Expectations (high level)
- Chat: messages or conversations list with role/content pairs.
- Preference: prompt + response_a/response_b or chosen/rejected conversations.
- Math: problem text + answer string; boxed answer extraction for MATH.
- Vision: image references and labels; decoding optional for training.
