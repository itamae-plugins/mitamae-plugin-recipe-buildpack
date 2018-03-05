# mitamae-plugin-recipe-buildpack

MItamae plugin to reproduce the behavior of https://github.com/yyuu/chef-buildpack

## Usage

See https://github.com/itamae-kitchen/mitamae/blob/v1.5.6/PLUGINS.md.

Put this repository as `./plugins/mitamae-plugin-recipe-buildpack`,
and execute `mitamae local` where you can find `./plugins` directory.

### Example

```rb
include_recipe 'buildpack'

buildpack 'app' do
  buildpack_url 'https://github.com/heroku/heroku-buildpack-ruby.git'
  build_dir '/home/k0kubun/heroku/buildpack'
end
```

## License

Copyright 2015 Yamashita, Yuu (yuu@treasure-data.com)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
