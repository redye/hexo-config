time=$(date "+%Y-%m-%d %H:%M:%S")
commitInfo="Site update: ${time}"
branch='master'

while getopts "m:b:" arg #选项后面的冒号表示该选项需要参数
do
	case $arg in
		m)
			commitInfo=${OPTARG}
			;;
		b)
			branch=${OPTARG}
			;;
		?)
			echo 'NOT KNOW'
			;;
	esac
done

hexo clean
hexo generate

cd .deploy/redye.github.io
git pull origin ${branch}
cp -R ../../public/* .

echo '==============================================================='
echo '======================== CURRENT PATH ========================='
pwd
echo '==============================================================='
echo '======================== COMMIT INFO =========================='
echo "${commitInfo}"
echo '==============================================================='
echo '======================== BRANCH ==============================='
echo "${branch}"
echo '==============================================================='

git add .
git commit -m "${commitInfo}"
git push origin ${branch}